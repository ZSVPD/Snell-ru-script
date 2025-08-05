#!/bin/bash
# =========================================
# Автор: jinqians
# Дата: 16 марта 2025
# Сайт: jinqians.com
# Описание: Этот скрипт предназначен для установки и управления ShadowTLS V3
# =========================================

# Определение цветовых кодов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Определение системных путей
INSTALL_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/shadowtls"
SERVICE_FILE="${SYSTEMD_DIR}/shadowtls.service"

# Определение каталога конфигурации
SNELL_CONF_DIR="/etc/snell"
SNELL_CONF_FILE="${SNELL_CONF_DIR}/users/snell-main.conf"
USERS_DIR="${SNELL_CONF_DIR}/users"

# Проверка, запущен ли скрипт от root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Пожалуйста, запустите этот скрипт от имени root${RESET}"
        exit 1
    fi
}

# Установка необходимых утилит
install_requirements() {
    apt update
    apt install -y wget curl jq
}

# Получение последней версии
get_latest_version() {
    latest_version=$(curl -s "https://api.github.com/repos/ihciah/shadow-tls/releases/latest" | jq -r .tag_name)
    if [ -z "$latest_version" ]; then
        echo -e "${RED}Не удалось получить последнюю версию${RESET}"
        exit 1
    fi
    echo "$latest_version"
}

# Проверка, установлен ли ss-rust
check_ssrust() {
    if [ ! -f "/usr/local/bin/ss-rust" ]; then
        return 1
    fi
    return 0
}

# Проверка, установлен ли Snell
check_snell() {
    if [ ! -f "/usr/local/bin/snell-server" ]; then
        return 1
    fi
    return 0
}

# Получение порта ss-rust
get_ssrust_port() {
    local ssrust_conf="/etc/ss-rust/config.json"
    if [ ! -f "$ssrust_conf" ]; then
        return 1
    fi
    local port=$(jq -r '.server_port' "$ssrust_conf" 2>/dev/null)
    echo "$port"
}

# Получение пароля ss-rust
get_ssrust_password() {
    local ssrust_conf="/etc/ss-rust/config.json"
    if [ ! -f "$ssrust_conf" ]; then
        return 1
    fi
    local password=$(jq -r '.password' "$ssrust_conf" 2>/dev/null)
    echo "$password"
}

# Получение метода шифрования ss-rust
get_ssrust_method() {
    local ssrust_conf="/etc/ss-rust/config.json"
    if [ ! -f "$ssrust_conf" ]; then
        return 1
    fi
    local method=$(jq -r '.method' "$ssrust_conf" 2>/dev/null)
    echo "$method"
}

# Получение порта Snell
get_snell_port() {
    if [ -f "${SNELL_CONF_FILE}" ]; then
        grep -E '^listen' "${SNELL_CONF_FILE}" | sed -n 's/.*::0:\([0-9]*\)/\1/p'
    fi
}

# Получение PSK Snell
get_snell_psk() {
    local snell_conf="/etc/snell/users/snell-main.conf"
    if [ ! -f "$snell_conf" ]; then
        return 1
    fi
    local psk=$(grep -E '^psk' "$snell_conf" | sed 's/psk = //')
    echo "$psk"
}

# Получение конфигурации Snell
get_snell_config() {
    local port=$1
    local snell_conf="${USERS_DIR}/snell-${port}.conf"
    local main_conf="${USERS_DIR}/snell-main.conf"
    
    # Попытка получить конфигурацию по порту, иначе использовать основную
    local psk=$(grep -E "^psk = " "$snell_conf" 2>/dev/null | sed 's/psk = //' || grep -E "^psk = " "$main_conf" 2>/dev/null | sed 's/psk = //')
    echo "$psk"
}

# Получение всех конфигураций пользователей Snell
get_all_snell_users() {
    # Проверка существования каталога конфигурации пользователей
    if [ ! -d "${USERS_DIR}" ]; then
        return 1
    fi
    
    # Сначала получить основную конфигурацию
    local main_port=""
    local main_psk=""
    if [ -f "${SNELL_CONF_FILE}" ]; then
        main_port=$(grep -E '^listen' "${SNELL_CONF_FILE}" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
        main_psk=$(grep -E '^psk' "${SNELL_CONF_FILE}" | awk -F'=' '{print $2}' | tr -d ' ')
        if [ ! -z "$main_port" ] && [ ! -z "$main_psk" ]; then
            echo "${main_port}|${main_psk}"
        fi
    fi
    
    # Получить конфигурации других пользователей
    for user_conf in "${USERS_DIR}"/snell-*.conf; do
        if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
            local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
            local psk=$(grep -E '^psk' "$user_conf" | awk -F'=' '{print $2}' | tr -d ' ')
            if [ ! -z "$port" ] && [ ! -z "$psk" ]; then
                echo "${port}|${psk}"
            fi
        fi
    done
}

# Получение версии Snell
get_snell_version() {
    if ! command -v snell-server &> /dev/null; then
        return 1
    fi
    
    # Попытка получить версию
    local version_output=$(snell-server --v 2>&1)
    
    # Проверка, является ли версией v5
    if echo "$version_output" | grep -q "v5"; then
        echo "5"
    else
        # По умолчанию считаем, что это версия v4
        echo "4"
    fi
}

# Получение IP-адреса сервера
get_server_ip() {
    local ipv4
    local ipv6
    
    # Получение IPv4
    ipv4=$(curl -s -4 ip.sb 2>/dev/null)
    
    # Получение IPv6
    ipv6=$(curl -s -6 ip.sb 2>/dev/null)
    
    # Определение типа IP и возврат
    if [ -n "$ipv4" ] && [ -n "$ipv6" ]; then
        # Двойной стек, отдаём IPv4 в приоритете
        echo "$ipv4"
    elif [ -n "$ipv4" ]; then
        # Только IPv4
        echo "$ipv4"
    elif [ -n "$ipv6" ]; then
        # Только IPv6
        echo "$ipv6"
    else
        echo -e "${RED}Не удалось получить IP-адрес сервера${RESET}"
        return 1
    fi
    
    return 0
}

# Проверка формата команды shadow-tls
check_shadowtls_command() {
    local help_output
    help_output=$($INSTALL_DIR/shadow-tls --help 2>&1)
    echo -e "${YELLOW}Справка по команде shadow-tls:${RESET}"
    echo "$help_output"
    return 0
}

# Генерация безопасного Base64-кода
urlsafe_base64() {
    date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
    echo -e "${date}"
}

# Генерация случайного порта
generate_random_port() {
    local min_port=10000
    local max_port=65535
    echo $(shuf -i ${min_port}-${max_port} -n 1)
}

# Проверка, занят ли порт
check_port_usage() {
    local port=$1
    if netstat -tuln | grep -q ":${port}"; then
        return 0  # Порт занят
    fi
    return 1     # Порт свободен
}

# Получение уже используемых портов ShadowTLS
get_used_stls_ports() {
    local used_ports=()
    
    # Проверка SS-сервиса
    local ss_service="${SYSTEMD_DIR}/shadowtls-ss.service"
    if [ -f "$ss_service" ]; then
        local ss_port=$(grep -oP '(?<=--listen ::0:)\d+' "$ss_service")
        if [ ! -z "$ss_port" ]; then
            used_ports+=("$ss_port")
        fi
    fi
    
    # Проверка Snell-сервисов
    local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null)
    if [ ! -z "$snell_services" ]; then
        while IFS= read -r service_file; do
            local port=$(grep -oP '(?<=--listen ::0:)\d+' "$service_file")
            if [ ! -z "$port" ]; then
                used_ports+=("$port")
            fi
        done <<< "$snell_services"
    fi
    
    echo "${used_ports[@]}"
}

# Проверка и получение доступного порта
get_available_port() {
    local port=$1
    local used_ports=($(get_used_stls_ports))
    
    # Если пользователь указал порт
    if [ ! -z "$port" ]; then
        # Проверка, не используется ли порт другим ShadowTLS
        for used_port in "${used_ports[@]}"; do
            if [ "$port" = "$used_port" ]; then
                echo -e "${RED}Порт ${port} уже используется другим сервисом ShadowTLS${RESET}"
                return 1
            fi
        done
        
        # Проверка, не занят ли порт другими сервисами
        if check_port_usage "$port"; then
            echo -e "${RED}Порт ${port} уже занят другим сервисом${RESET}"
            return 1
        fi
        
        echo "$port"
        return 0
    fi
    
    # Если порт не указан — попытка сгенерировать случайный
    local attempts=0
    while [ $attempts -lt 10 ]; do
        local random_port=$(generate_random_port)
        local is_used=0
        
        # Проверка, используется ли порт ShadowTLS
        for used_port in "${used_ports[@]}"; do
            if [ "$random_port" = "$used_port" ]; then
                is_used=1
                break
            fi
        done
        
        # Если порт свободен
        if [ $is_used -eq 0 ] && ! check_port_usage "$random_port"; then
            echo "$random_port"
            return 0
        fi
        
        attempts=$((attempts + 1))
    done
    
    echo -e "${RED}Не удалось найти доступный порт${RESET}"
    return 1
}

# Генерация ссылки и конфигурации для Shadowsocks
generate_ss_links() {
    local server_ip=$1
    local listen_port=$2
    local ssrust_password=$3
    local ssrust_method=$4
    local stls_password=$5
    local stls_sni=$6
    local backend_port=$7

    echo -e "\n${YELLOW}=== Конфигурация сервера ===${RESET}"
    echo -e "IP сервера: ${server_ip}"
    echo -e "\nКонфигурация Shadowsocks:"
    echo -e "  - Порт: ${backend_port}"
    echo -e "  - Метод шифрования: ${ssrust_method}"
    echo -e "  - Пароль: ${ssrust_password}"
    echo -e "\nКонфигурация ShadowTLS:"
    echo -e "  - Порт: ${listen_port}"
    echo -e "  - Пароль: ${stls_password}"
    echo -e "  - SNI: ${stls_sni}"
    echo -e "  - Версия: 3"

    # Генерация объединённой ссылки SS + ShadowTLS
    local userinfo=$(echo -n "${ssrust_method}:${ssrust_password}" | base64 | tr -d '\n')
    local shadow_tls_config="{\"version\":\"3\",\"password\":\"${stls_password}\",\"host\":\"${stls_sni}\",\"port\":\"${listen_port}\",\"address\":\"${server_ip}\"}"
    local shadow_tls_base64=$(echo -n "${shadow_tls_config}" | base64 | tr -d '\n')
    local ss_url="ss://${userinfo}@${server_ip}:${backend_port}?shadow-tls=${shadow_tls_base64}#SS-${server_ip}"

    echo -e "\n${YELLOW}=== Конфигурация для Surge ===${RESET}"
    echo -e "SS-${server_ip} = ss, ${server_ip}, ${listen_port}, encrypt-method=${ssrust_method}, password=${ssrust_password}, shadow-tls-password=${stls_password}, shadow-tls-sni=${stls_sni}, shadow-tls-version=3, udp-relay=true"

    echo -e "\n${YELLOW}=== Инструкция для Shadowrocket ===${RESET}"
    echo -e "1. Добавьте Shadowsocks-узел:"
    echo -e "   - Тип: Shadowsocks"
    echo -e "   - Адрес: ${server_ip}"
    echo -e "   - Порт: ${backend_port}"
    echo -e "   - Метод шифрования: ${ssrust_method}"
    echo -e "   - Пароль: ${ssrust_password}"

    echo -e "\n2. Добавьте узел ShadowTLS:"
    echo -e "   - Тип: ShadowTLS"
    echo -e "   - Адрес: ${server_ip}"
    echo -e "   - Порт: ${listen_port}"
    echo -e "   - Пароль: ${stls_password}"
    echo -e "   - SNI: ${stls_sni}"
    echo -e "   - Версия: 3"

    echo -e "\n${YELLOW}=== Ссылка для Shadowrocket ===${RESET}"
    echo -e "${GREEN}SS + ShadowTLS ссылка:${RESET}${ss_url}"

    echo -e "\n${YELLOW}=== QR-код для Shadowrocket ===${RESET}"
    qrencode -t UTF8 "${ss_url}"

    echo -e "\n${YELLOW}=== Конфигурация для Clash Meta ===${RESET}"
    echo -e "proxies:"
    echo -e "  - name: SS-${server_ip}"
    echo -e "    type: ss"
    echo -e "    server: ${server_ip}"
    echo -e "    port: ${listen_port}"
    echo -e "    cipher: ${ssrust_method}"
    echo -e "    password: \"${ssrust_password}\""
    echo -e "    plugin: shadow-tls"
    echo -e "    plugin-opts:"
    echo -e "      host: \"${stls_sni}\""
    echo -e "      password: \"${stls_password}\""
    echo -e "      version: 3"
}

# Генерация ссылки и конфигурации для Snell
generate_snell_links() {
    local server_ip=$1
    local listen_port=$2
    local snell_psk=$3
    local stls_password=$4
    local stls_sni=$5
    local backend_port=$6

    # Получение версии Snell
    local snell_version=$(get_snell_version)

    echo -e "\n${YELLOW}=== Конфигурация сервера ===${RESET}"
    echo -e "IP сервера: ${server_ip}"
    echo -e "\nКонфигурация Snell:"
    echo -e "  - Порт: ${backend_port}"
    echo -e "  - PSK: ${snell_psk}"
    echo -e "  - Версия: ${snell_version}"
    echo -e "\nКонфигурация ShadowTLS:"
    echo -e "  - Порт: ${listen_port}"
    echo -e "  - Пароль: ${stls_password}"
    echo -e "  - SNI: ${stls_sni}"
    echo -e "  - Версия: 3"

    echo -e "\n${YELLOW}=== Конфигурация для Surge ===${RESET}"
    
    # Версия v5 выводит формат v4 и v5, версия v4 — только v4
    if [ "$snell_version" = "5" ]; then
        echo -e "Snell v4 + ShadowTLS = snell, ${server_ip}, ${listen_port}, psk = ${snell_psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_sni}, shadow-tls-version = 3"
        echo -e "Snell v5 + ShadowTLS = snell, ${server_ip}, ${listen_port}, psk = ${snell_psk}, version = 5, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_sni}, shadow-tls-version = 3"
    else
        echo -e "Snell + ShadowTLS = snell, ${server_ip}, ${listen_port}, psk = ${snell_psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_sni}, shadow-tls-version = 3"
    fi
}

# Шаблон создания service-файла
create_shadowtls_service() {
    local service_type=$1  # ss или snell
    local port=$2
    local listen_port=$3
    local tls_domain=$4
    local password=$5
    local service_file
    local description
    local identifier

    if [ "$service_type" = "ss" ]; then
        service_file="${SYSTEMD_DIR}/shadowtls-ss.service"
        description="Сервис Shadow-TLS для Shadowsocks"
        identifier="shadow-tls-ss"
    else
        service_file="${SYSTEMD_DIR}/shadowtls-snell-${port}.service"
        description="Сервис Shadow-TLS для Snell (порт: ${port})"
        identifier="shadow-tls-snell-${port}"
    fi

    cat > "$service_file" << EOF
[Unit]
Description=${description}
Documentation=man:sstls-server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
Environment=RUST_BACKTRACE=1
Environment=RUST_LOG=info
ExecStart=/usr/local/bin/shadow-tls --v3 server --listen ::0:${listen_port} --server 127.0.0.1:${port} --tls ${tls_domain} --password ${password}
StandardOutput=append:/var/log/shadowtls-${identifier}.log
StandardError=append:/var/log/shadowtls-${identifier}.log
SyslogIdentifier=${identifier}
Restart=always
RestartSec=3

# Параметры оптимизации производительности
LimitNOFILE=65535
CPUAffinity=0
Nice=0
IOSchedulingClass=realtime
IOSchedulingPriority=0
MemoryLimit=512M
CPUQuota=50%
LimitCORE=infinity
LimitRSS=infinity
LimitNPROC=65535
LimitAS=infinity
SystemCallFilter=@system-service
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Параметры оптимизации системы
Environment=RUST_THREADS=1
Environment=MONOIO_FORCE_LEGACY_DRIVER=1
Environment=RUST_LOG_LEVEL=info
Environment=RUST_LOG_TARGET=journal
Environment=RUST_LOG_FORMAT=json
Environment=RUST_LOG_FILTER=info,shadow_tls=info

[Install]
WantedBy=multi-user.target
EOF

    # Создание лог-файла и установка прав
    touch "/var/log/shadowtls-${identifier}.log"
    chmod 640 "/var/log/shadowtls-${identifier}.log"
    chown root:root "/var/log/shadowtls-${identifier}.log"
}

# Установка ShadowTLS
install_shadowtls() {
    echo -e "${CYAN}Установка ShadowTLS...${RESET}"

    # Проверка установленных протоколов
    local has_ss=false
    local has_snell=false

    if check_ssrust; then
        has_ss=true
        echo -e "${GREEN}Обнаружен установленный Shadowsocks Rust${RESET}"
    fi

    if check_snell; then
        has_snell=true
        echo -e "${GREEN}Обнаружен установленный Snell${RESET}"
    fi

    if ! $has_ss && ! $has_snell; then
        echo -e "${RED}Не обнаружен Shadowsocks Rust или Snell. Пожалуйста, установите хотя бы один из них.${RESET}"
        return 1
    fi

    # Получение архитектуры системы и загрузка ShadowTLS
    arch=$(uname -m)
    case $arch in
        x86_64)
            arch="x86_64-unknown-linux-musl"
            ;;
        aarch64)
            arch="aarch64-unknown-linux-musl"
            ;;
        *)
            echo -e "${RED}Неподдерживаемая архитектура: $arch${RESET}"
            exit 1
            ;;
    esac

    # Получение последней версии
    version=$(get_latest_version)

    # Загрузка и установка
    download_url="https://github.com/ihciah/shadow-tls/releases/download/${version}/shadow-tls-${arch}"
    wget "$download_url" -O "/tmp/shadow-tls.tmp"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка загрузки ShadowTLS${RESET}"
        exit 1
    fi

    # Перемещение и установка прав
    mv "/tmp/shadow-tls.tmp" "$INSTALL_DIR/shadow-tls"
    chmod +x "$INSTALL_DIR/shadow-tls"

    # Генерация случайного пароля
    password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

    # Запрос TLS-домена
    read -rp "Введите TLS-домен (по умолчанию www.microsoft.com): " tls_domain
    if [ -z "$tls_domain" ]; then
        tls_domain="www.microsoft.com"
    fi

    # Выбор протокола для настройки
    while true; do
        echo -e "\n${YELLOW}Выберите протокол для настройки:${RESET}"
        echo -e "1. Настроить ShadowTLS для Shadowsocks"
        echo -e "2. Настроить ShadowTLS для Snell"
        echo -e "3. Настроить ShadowTLS для обоих"
        echo -e "0. Выход"

        read -rp "Ваш выбор [0-3]: " protocol_choice

        case "$protocol_choice" in
            0)
                return 0
                ;;
            1)
                if ! $has_ss; then
                    echo -e "${RED}Shadowsocks не установлен${RESET}"
                    continue
                fi
                configure_ss=true
                configure_snell=false
                break
                ;;
            2)
                if ! $has_snell; then
                    echo -e "${RED}Snell не установлен${RESET}"
                    continue
                fi
                configure_ss=false
                configure_snell=true
                break
                ;;
            3)
                if ! $has_ss || ! $has_snell; then
                    echo -e "${RED}Для этого действия необходимо установить и Shadowsocks, и Snell${RESET}"
                    continue
                fi
                configure_ss=true
                configure_snell=true
                break
                ;;
            *)
                echo -e "${RED}Недопустимый выбор${RESET}"
                ;;
        esac
    done
    
    # Настройка Shadowsocks
    if $configure_ss; then
        echo -e "\n${YELLOW}Настройка ShadowTLS для Shadowsocks...${RESET}"
        while true; do
            read -rp "Введите порт прослушивания ShadowTLS (1–65535, Enter — для случайного): " ss_listen_port

            # Проверка и получение доступного порта
            ss_listen_port=$(get_available_port "$ss_listen_port")
            if [ $? -eq 0 ]; then
                break
            fi
            echo -e "${YELLOW}Пожалуйста, введите другой порт${RESET}"
        done

        echo -e "${GREEN}Будет использоваться порт: ${ss_listen_port}${RESET}"

        # Создание ShadowTLS-сервиса для SS
        local ss_port=$(get_ssrust_port)
        create_shadowtls_service "ss" "$ss_port" "$ss_listen_port" "$tls_domain" "$password"
        systemctl start shadowtls-ss
        systemctl enable shadowtls-ss
    fi

    # Настройка Snell
    if $configure_snell; then
        echo -e "\n${YELLOW}Настройка ShadowTLS для Snell...${RESET}"

        # Получение конфигураций пользователей Snell
        local user_configs=$(get_all_snell_users)
        if [ -z "$user_configs" ]; then
            echo -e "${RED}Не найдены действительные конфигурации пользователей Snell${RESET}"
            return 1
        fi

        # Вывод всех портов Snell
        echo -e "\n${YELLOW}Текущий список портов Snell:${RESET}"
        local port_list=()
        while IFS='|' read -r port psk; do
            if [ ! -z "$port" ]; then
                port_list+=("$port")
                if [ "$port" = "$(get_snell_port)" ]; then
                    echo -e "${GREEN}${#port_list[@]}. ${port} (основной пользователь)${RESET}"
                else
                    echo -e "${GREEN}${#port_list[@]}. ${port}${RESET}"
                fi
            fi
        done <<< "$user_configs"

        # Выбор порта для настройки
        echo -e "\n${YELLOW}Выберите порт для настройки:${RESET}"
        echo -e "1-${#port_list[@]}. Настроить один порт"
        echo -e "0. Настроить ShadowTLS для всех портов"

        read -rp "Ваш выбор: " port_choice

        if [ "$port_choice" = "0" ]; then
            # Настройка ShadowTLS для всех портов
            for port in "${port_list[@]}"; do
                echo -e "\n${YELLOW}Настройка ShadowTLS для порта Snell ${port}${RESET}"
                while true; do
                    read -rp "Введите порт прослушивания ShadowTLS (1–65535, Enter — случайный): " stls_port

                    # Проверка и получение доступного порта
                    stls_port=$(get_available_port "$stls_port")
                    if [ $? -eq 0 ]; then
                        break
                    fi
                    echo -e "${YELLOW}Пожалуйста, введите другой порт${RESET}"
                done

                echo -e "${GREEN}Будет использоваться порт: ${stls_port}${RESET}"

                # Создание файла службы
                create_shadowtls_service "snell" "$port" "$stls_port" "$tls_domain" "$password"
                systemctl start "shadowtls-snell-${port}"
                systemctl enable "shadowtls-snell-${port}"
            done
        elif [[ "$port_choice" =~ ^[0-9]+$ ]] && [ "$port_choice" -ge 1 ] && [ "$port_choice" -le ${#port_list[@]} ]; then
            # Настройка ShadowTLS для выбранного порта
            local selected_port="${port_list[$((port_choice-1))]}"
            echo -e "\n${YELLOW}Настройка ShadowTLS для порта Snell ${selected_port}${RESET}"
            while true; do
                read -rp "Введите порт прослушивания ShadowTLS (1–65535, Enter — случайный): " stls_port

                # Проверка и получение доступного порта
                stls_port=$(get_available_port "$stls_port")
                if [ $? -eq 0 ]; then
                    break
                fi
                echo -e "${YELLOW}Пожалуйста, введите другой порт${RESET}"
            done

            echo -e "${GREEN}Будет использоваться порт: ${stls_port}${RESET}"

            # Создание файла службы
            create_shadowtls_service "snell" "$selected_port" "$stls_port" "$tls_domain" "$password"
            systemctl start "shadowtls-snell-${selected_port}"
            systemctl enable "shadowtls-snell-${selected_port}"
        else
            echo -e "${RED}Неверный выбор${RESET}"
            return 1
        fi
    fi
    
    # 重新加载 systemd 配置
    systemctl daemon-reload
    
    # 获取服务器IP
    local server_ip=$(get_server_ip)
    
    echo -e "\n${GREEN}=== ShadowTLS 安装成功 ===${RESET}"
    
    # 显示所有可用的配置
    if $configure_ss; then
        local ssrust_password=$(get_ssrust_password)
        local ssrust_method=$(get_ssrust_method)
        local ss_port=$(get_ssrust_port)
        generate_ss_links "${server_ip}" "${ss_listen_port}" "${ssrust_password}" "${ssrust_method}" "${password}" "${tls_domain}" "${ss_port}"
    fi
    
    if $configure_snell; then
        while IFS='|' read -r port psk; do
            if [ ! -z "$port" ]; then
                local service_file="${SYSTEMD_DIR}/shadowtls-snell-${port}.service"
                if [ -f "$service_file" ]; then
                    local stls_port=$(grep -oP '(?<=--listen ::0:)\d+' "$service_file")
                    generate_snell_links "${server_ip}" "${stls_port}" "${psk}" "${password}" "${tls_domain}" "${port}"
                fi
            fi
        done <<< "$user_configs"
    fi

    echo -e "\n${GREEN}服务已启动并设置为开机自启${RESET}"
}

# 卸载 ShadowTLS
uninstall_shadowtls() {
    echo -e "${CYAN}正在卸载 ShadowTLS...${RESET}"
    
    # 停止并禁用 SS 服务
    if [ -f "${SYSTEMD_DIR}/shadowtls-ss.service" ]; then
        systemctl stop shadowtls-ss 2>/dev/null
        systemctl disable shadowtls-ss 2>/dev/null
        rm -f "${SYSTEMD_DIR}/shadowtls-ss.service"
    fi
    
    # 停止并禁用所有 Snell 相关的 ShadowTLS 服务
    local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null)
    if [ ! -z "$snell_services" ]; then
        while IFS= read -r service_file; do
            local service_name=$(basename "$service_file")
            systemctl stop "$service_name" 2>/dev/null
            systemctl disable "$service_name" 2>/dev/null
            rm -f "$service_file"
        done <<< "$snell_services"
    fi
    
    # 删除二进制文件
    rm -f "$INSTALL_DIR/shadow-tls"
    
    # 重新加载 systemd 配置
    systemctl daemon-reload
    
    echo -e "${GREEN}ShadowTLS 已成功卸载${RESET}"
}

# 查看配置
view_config() {
    echo -e "${CYAN}正在获取配置信息...${RESET}"
    
    # 检查服务是否安装
    local ss_service="${SYSTEMD_DIR}/shadowtls-ss.service"
    local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null | sort -u)
    
    if [ ! -f "$ss_service" ] && [ -z "$snell_services" ]; then
        echo -e "${RED}ShadowTLS 未安装${RESET}"
        return 1
    fi
    
    # 获取服务器IP
    local server_ip=$(get_server_ip)
    
    # 检查 SS 是否安装并获取配置
    if [ -f "$ss_service" ] && check_ssrust; then
        echo -e "\n${YELLOW}=== Shadowsocks + ShadowTLS 配置 ===${RESET}"
        local ss_listen_port=$(grep -oP '(?<=--listen ::0:)\d+' "$ss_service")
        local tls_domain=$(grep -oP '(?<=--tls )[^ ]+' "$ss_service")
        local password=$(grep -oP '(?<=--password )[^ ]+' "$ss_service")
        local ss_port=$(get_ssrust_port)
        local ssrust_password=$(get_ssrust_password)
        local ssrust_method=$(get_ssrust_method)
        
        if [ ! -z "$ss_listen_port" ] && [ ! -z "$tls_domain" ] && [ ! -z "$password" ]; then
            generate_ss_links "${server_ip}" "${ss_listen_port}" "${ssrust_password}" "${ssrust_method}" "${password}" "${tls_domain}" "${ss_port}"
        else
            echo -e "${RED}SS 配置文件不完整或已损坏${RESET}"
        fi
    fi
    
    # Проверка, установлен ли Snell, и получение конфигурации
    if [ ! -z "$snell_services" ] && check_snell; then
        echo -e "\n${YELLOW}=== Конфигурация Snell + ShadowTLS ===${RESET}"

        # Получение всех пользовательских конфигураций
        local user_configs=$(get_all_snell_users)
        if [ ! -z "$user_configs" ]; then
            # Создание ассоциативного массива для хранения уже обработанных портов
            declare -A processed_ports

            while IFS='|' read -r port psk; do
                if [ ! -z "$port" ] && [ -z "${processed_ports[$port]}" ]; then
                    processed_ports[$port]=1

                    # Получение конфигурации соответствующего ShadowTLS-сервиса
                    local service_file="${SYSTEMD_DIR}/shadowtls-snell-${port}.service"
                    if [ -f "$service_file" ]; then
                        local exec_line=$(grep "ExecStart=" "$service_file")
                        local stls_port=$(echo "$exec_line" | grep -oP '(?<=--listen ::0:)\d+')
                        local stls_password=$(echo "$exec_line" | grep -oP '(?<=--password )[^ ]+')
                        local stls_domain=$(echo "$exec_line" | grep -oP '(?<=--tls )[^ ]+')

                        if [ "$port" = "$(get_snell_port)" ]; then
                            echo -e "\n${GREEN}Конфигурация основного пользователя:${RESET}"
                        else
                            echo -e "\n${GREEN}Конфигурация пользователя (порт Snell: ${port}):${RESET}"
                        fi

                        if [ ! -z "$stls_port" ] && [ ! -z "$stls_password" ] && [ ! -z "$stls_domain" ]; then
                            echo -e "${YELLOW}Конфигурация Snell:${RESET}"
                            echo -e "  - Порт: ${port}"
                            echo -e "  - PSK: ${psk}"

                            echo -e "\n${YELLOW}Конфигурация ShadowTLS:${RESET}"
                            echo -e "  - Порт прослушивания: ${stls_port}"
                            echo -e "  - Пароль: ${stls_password}"
                            echo -e "  - SNI: ${stls_domain}"
                            echo -e "  - Версия: 3"

                            echo -e "\n${GREEN}Конфигурация для Surge:${RESET}"
                            local snell_version=$(get_snell_version)
                            if [ "$snell_version" = "5" ]; then
                                echo -e "Snell v4 + ShadowTLS = snell, ${server_ip}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3"
                                echo -e "Snell v5 + ShadowTLS = snell, ${server_ip}, ${stls_port}, psk = ${psk}, version = 5, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3"
                            else
                                echo -e "Snell + ShadowTLS = snell, ${server_ip}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3"
                            fi
                            
                            # Проверка состояния службы
                            local service_status=$(systemctl is-active "shadowtls-snell-${port}")
                            if [ "$service_status" = "active" ]; then
                                echo -e "\n${GREEN}Состояние службы: работает${RESET}"
                                # Проверка использования порта
                                local port_usage=$(netstat -tuln | grep ":${stls_port}")
                                local port_count=$(echo "$port_usage" | wc -l)
                                if [ "$port_count" -gt 1 ]; then
                                    echo -e "${RED}Внимание: порт ${stls_port} используется несколькими службами!${RESET}"
                                    echo -e "${YELLOW}Информация по использованию порта:${RESET}"
                                    netstat -tuln | grep ":${stls_port}"
                                fi
                            else
                                echo -e "\n${RED}Служба не запущена${RESET}"
                                echo -e "${YELLOW}Попробуйте перезапустить службу с помощью команды:${RESET}"
                                echo -e "systemctl restart shadowtls-snell-${port}"
                            fi
                        else
                            echo -e "${RED}Конфигурационный файл неполный или повреждён${RESET}"
                        fi
                    else
                        echo -e "\n${YELLOW}Не найден файл конфигурации ShadowTLS для пользователя (порт: ${port})${RESET}"
                    fi
                fi
            done <<< "$user_configs"
        else
            echo -e "\n${YELLOW}Не найдено ни одной действительной конфигурации пользователя Snell${RESET}"
        fi
    fi

    # Отображение состояния всех служб
    echo -e "\n${YELLOW}=== Состояние служб ShadowTLS ===${RESET}"

    # Состояние службы Shadowsocks
    if [ -f "$ss_service" ]; then
        echo -e "\n${YELLOW}Состояние службы Shadowsocks:${RESET}"
        systemctl status shadowtls-ss --no-pager

        # Если служба не запущена — подсказка по перезапуску
        if [ "$(systemctl is-active shadowtls-ss)" != "active" ]; then
            echo -e "\n${YELLOW}Служба Shadowsocks не запущена. Попробуйте выполнить:${RESET}"
            echo -e "systemctl restart shadowtls-ss"
        fi
    fi

    # Состояние всех служб Snell (без повторов)
    if [ ! -z "$snell_services" ]; then
        echo -e "\n${YELLOW}Состояние служб Snell:${RESET}"
        declare -A shown_services
        while IFS= read -r service_file; do
            local port=$(basename "$service_file" | sed 's/shadowtls-snell-\([0-9]*\)\.service/\1/')
            if [ -z "${shown_services[$port]}" ]; then
                shown_services[$port]=1
                echo -e "\n${GREEN}Состояние ShadowTLS для порта Snell ${port}:${RESET}"
                systemctl status "shadowtls-snell-${port}" --no-pager
                
                # Если служба не запущена, показать команду перезапуска
                if [ "$(systemctl is-active shadowtls-snell-${port})" != "active" ]; then
                    echo -e "\n${YELLOW}Служба не запущена, попробуйте перезапустить командой:${RESET}"
                    echo -e "systemctl restart shadowtls-snell-${port}"
                fi
            fi
        done <<< "$snell_services"
    fi
}

# Добавить конфигурацию ShadowTLS
add_shadowtls_config() {
    echo -e "${CYAN}Добавление конфигурации ShadowTLS...${RESET}"
    
    # Проверка установленных протоколов
    local has_ss=false
    local has_snell=false
    local has_ss_stls=false
    
    if check_ssrust; then
        has_ss=true
        echo -e "${GREEN}Обнаружен установленный Shadowsocks Rust${RESET}"
        if [ -f "${SYSTEMD_DIR}/shadowtls-ss.service" ]; then
            has_ss_stls=true
            echo -e "${YELLOW}Конфигурация ShadowTLS для Shadowsocks уже существует${RESET}"
        fi
    fi
    
    if check_snell; then
        has_snell=true
        echo -e "${GREEN}Обнаружен установленный Snell${RESET}"
    fi
    
    if ! $has_ss && ! $has_snell; then
        echo -e "${RED}Не обнаружены Shadowsocks Rust или Snell. Установите один из них.${RESET}"
        return 1
    fi
    
    # Предложить пользователю выбрать протокол для добавления конфигурации ShadowTLS
    while true; do
        echo -e "\n${YELLOW}Выберите протокол для добавления конфигурации:${RESET}"
        if $has_ss && ! $has_ss_stls; then
            echo -e "1. Добавить конфигурацию ShadowTLS для Shadowsocks"
        fi
        if $has_snell; then
            echo -e "2. Добавить конфигурацию ShadowTLS для Snell"
        fi
        echo -e "0. Назад"
        
        read -rp "Пожалуйста, выберите: " choice
        
        case "$choice" in
            0)
                return 0
                ;;
            1)
                if ! $has_ss || $has_ss_stls; then
                    echo -e "${RED}Недопустимый выбор${RESET}"
                    continue
                fi
                # Получение необходимых параметров конфигурации
                password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
                read -rp "Введите домен для TLS-маскировки (по умолчанию www.microsoft.com): " tls_domain
                if [ -z "$tls_domain" ]; then
                    tls_domain="www.microsoft.com"
                fi
                
                # Конфигурация ShadowTLS для Shadowsocks
                while true; do
                    read -rp "Введите порт для прослушивания ShadowTLS (1–65535, оставить пустым для случайного): " ss_listen_port
                    
                    # Проверка и получение доступного порта
                    ss_listen_port=$(get_available_port "$ss_listen_port")
                    if [ $? -eq 0 ]; then
                        break
                    fi
                    echo -e "${YELLOW}Пожалуйста, введите порт повторно${RESET}"
                done
                
                # Создание службы ShadowTLS для Shadowsocks
                local ss_port=$(get_ssrust_port)
                create_shadowtls_service "ss" "$ss_port" "$ss_listen_port" "$tls_domain" "$password"
                systemctl start shadowtls-ss
                systemctl enable shadowtls-ss
                
                # Отображение информации о конфигурации
                local server_ip=$(get_server_ip)
                local ssrust_password=$(get_ssrust_password)
                local ssrust_method=$(get_ssrust_method)
                generate_ss_links "${server_ip}" "${ss_listen_port}" "${ssrust_password}" "${ssrust_method}" "${password}" "${tls_domain}" "${ss_port}"
                break
                ;;
            2)
                if ! $has_snell; then
                    echo -e "${RED}Недопустимый выбор${RESET}"
                    continue
                fi
                
                # Получение необходимых параметров конфигурации
                password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
                read -rp "Введите домен для TLS-маскировки (по умолчанию www.microsoft.com): " tls_domain
                if [ -z "$tls_domain" ]; then
                    tls_domain="www.microsoft.com"
                fi
                
                # Получить все пользовательские конфигурации Snell
                local user_configs=$(get_all_snell_users)
                if [ -z "$user_configs" ]; then
                    echo -e "${RED}Не найдены допустимые пользовательские конфигурации Snell${RESET}"
                    return 1
                fi
                
                # Показать все порты Snell без конфигурации ShadowTLS
                echo -e "\n${YELLOW}Список портов Snell без конфигурации ShadowTLS:${RESET}"
                local port_list=()
                local port_count=0
                while IFS='|' read -r port psk; do
                    if [ ! -z "$port" ] && [ ! -f "${SYSTEMD_DIR}/shadowtls-snell-${port}.service" ]; then
                        port_list+=("$port")
                        if [ "$port" = "$(get_snell_port)" ]; then
                            echo -e "${GREEN}$((++port_count)). ${port} (основной пользователь)${RESET}"
                        else
                            echo -e "${GREEN}$((++port_count)). ${port}${RESET}"
                        fi
                    fi
                done <<< "$user_configs"
                
                if [ ${#port_list[@]} -eq 0 ]; then
                    echo -e "${YELLOW}Все порты Snell уже настроены для ShadowTLS${RESET}"
                    return 0
                fi
                
                # Предложить пользователю выбрать порт для настройки
                echo -e "\n${YELLOW}Выберите порт для настройки:${RESET}"
                echo -e "1-${#port_list[@]}. Настроить конкретный порт"
                echo -e "0. Настроить ShadowTLS для всех неподключённых портов"
                
                read -rp "Пожалуйста, выберите: " port_choice
                
                if [ "$port_choice" = "0" ]; then
                    # Настроить ShadowTLS для всех неподключённых портов
                    for port in "${port_list[@]}"; do
                        echo -e "\n${YELLOW}Настройка ShadowTLS для порта Snell ${port}${RESET}"
                        while true; do
                            read -rp "Введите порт для прослушивания ShadowTLS (1–65535, оставить пустым для случайного): " stls_port
                            
                            # Проверка и получение доступного порта
                            stls_port=$(get_available_port "$stls_port")
                            if [ $? -eq 0 ]; then
                                break
                            fi
                            echo -e "${YELLOW}Пожалуйста, введите порт повторно${RESET}"
                        done
                        
                        # Создание файла службы
                        create_shadowtls_service "snell" "$port" "$stls_port" "$tls_domain" "$password"
                        systemctl start "shadowtls-snell-${port}"
                        systemctl enable "shadowtls-snell-${port}"
                        
                        # Отображение информации о конфигурации
                        local server_ip=$(get_server_ip)
                        local psk=$(grep -E "^psk = " "/etc/snell/users/snell-${port}.conf" 2>/dev/null | sed 's/psk = //' || grep -E "^psk = " "/etc/snell/users/snell-main.conf" 2>/dev/null | sed 's/psk = //')
                        generate_snell_links "${server_ip}" "${stls_port}" "${psk}" "${password}" "${tls_domain}" "${port}"
                    done
                elif [[ "$port_choice" =~ ^[0-9]+$ ]] && [ "$port_choice" -ge 1 ] && [ "$port_choice" -le ${#port_list[@]} ]; then
                    # Настроить ShadowTLS для выбранного порта
                    local selected_port="${port_list[$((port_choice-1))]}"
                    echo -e "\n${YELLOW}Настройка ShadowTLS для порта Snell ${selected_port}${RESET}"
                    while true; do
                        read -rp "Введите порт для прослушивания ShadowTLS (1–65535, оставить пустым для случайного): " stls_port
                        
                        # Проверка и получение доступного порта
                        stls_port=$(get_available_port "$stls_port")
                        if [ $? -eq 0 ]; then
                            break
                        fi
                        echo -e "${YELLOW}Пожалуйста, введите порт повторно${RESET}"
                    done
                    
                    # Создание файла службы
                    create_shadowtls_service "snell" "$selected_port" "$stls_port" "$tls_domain" "$password"
                    systemctl start "shadowtls-snell-${selected_port}"
                    systemctl enable "shadowtls-snell-${selected_port}"
                    
                    # Отображение информации о конфигурации
                    local server_ip=$(get_server_ip)
                    local psk=$(grep -E "^psk = " "/etc/snell/users/snell-${selected_port}.conf" 2>/dev/null | sed 's/psk = //' || grep -E "^psk = " "/etc/snell/users/snell-main.conf" 2>/dev/null | sed 's/psk = //')
                    generate_snell_links "${server_ip}" "${stls_port}" "${psk}" "${password}" "${tls_domain}" "${selected_port}"
                else
                    echo -e "${RED}Недопустимый выбор${RESET}"
                    continue
                fi
                break
                ;;
            *)
                echo -e "${RED}Недопустимый выбор${RESET}"
                ;;
        esac
    done
    
    # Перезагрузка конфигурации systemd
    systemctl daemon-reload
    echo -e "\n${GREEN}Добавление конфигурации завершено${RESET}"
}

# Перезапуск служб ShadowTLS
restart_shadowtls_services() {
    echo -e "${CYAN}Перезапуск служб ShadowTLS...${RESET}"
    
    local has_services=false
    
    # Перезапуск службы SS
    if [ -f "${SYSTEMD_DIR}/shadowtls-ss.service" ]; then
        has_services=true
        echo -e "\n${YELLOW}Перезапуск службы ShadowTLS для Shadowsocks...${RESET}"
        systemctl restart shadowtls-ss
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Служба ShadowTLS для Shadowsocks успешно перезапущена${RESET}"
        else
            echo -e "${RED}Не удалось перезапустить службу ShadowTLS для Shadowsocks${RESET}"
        fi
    fi
    
    # Перезапуск всех служб Snell
    local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null)
    if [ ! -z "$snell_services" ]; then
        has_services=true
        echo -e "\n${YELLOW}Перезапуск служб ShadowTLS для Snell...${RESET}"
        while IFS= read -r service_file; do
            local port=$(basename "$service_file" | sed 's/shadowtls-snell-\([0-9]*\)\.service/\1/')
            echo -e "Перезапуск службы на порту ${port}..."
            systemctl restart "shadowtls-snell-${port}"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Служба на порту ${port} успешно перезапущена${RESET}"
            else
                echo -e "${RED}Сбой при перезапуске службы на порту ${port}${RESET}"
            fi
        done <<< "$snell_services"
    fi
    
    if ! $has_services; then
        echo -e "${RED}Службы ShadowTLS не найдены${RESET}"
        return 1
    fi
    
    echo -e "\n${GREEN}Все службы успешно перезапущены${RESET}"
    
    # Отображение статуса всех служб
    echo -e "\n${YELLOW}Статус служб:${RESET}"
    if [ -f "${SYSTEMD_DIR}/shadowtls-ss.service" ]; then
        echo -e "\n${CYAN}Статус службы ShadowTLS для Shadowsocks:${RESET}"
        systemctl status shadowtls-ss --no-pager
    fi
    
    if [ ! -z "$snell_services" ]; then
        while IFS= read -r service_file; do
            local port=$(basename "$service_file" | sed 's/shadowtls-snell-\([0-9]*\)\.service/\1/')
            echo -e "\n${CYAN}Статус службы ShadowTLS для Snell на порту ${port}:${RESET}"
            systemctl status "shadowtls-snell-${port}" --no-pager
        done <<< "$snell_services"
    fi
}

# Главное меню
main_menu() {
    while true; do
        echo -e "\n${CYAN}Меню управления ShadowTLS${RESET}"
        echo -e "${YELLOW}1. Установить ShadowTLS${RESET}"
        echo -e "${YELLOW}2. Удалить ShadowTLS${RESET}"
        echo -e "${YELLOW}3. Просмотреть конфигурации${RESET}"
        echo -e "${YELLOW}4. Добавить конфигурацию${RESET}"
        echo -e "${YELLOW}5. Перезапустить службы${RESET}"
        echo -e "${YELLOW}6. Вернуться в предыдущее меню${RESET}"
        echo -e "${YELLOW}0. Выход${RESET}"
        
        read -rp "Выберите действие [0-6]: " choice
        
        case "$choice" in
            1)
                install_shadowtls
                ;;
            2)
                uninstall_shadowtls
                ;;
            3)
                view_config
                ;;
            4)
                add_shadowtls_config
                ;;
            5)
                restart_shadowtls_services
                ;;
            6)
                return 0
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${RED}Недопустимый выбор${RESET}"
                ;;
        esac
    done
}

# Проверка прав root
check_root

# Если скрипт запущен напрямую, показать главное меню
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_menu
fi
