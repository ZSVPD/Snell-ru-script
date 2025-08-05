#!/bin/bash
# =========================================
# Автор: jinqians
# Дата: февраль 2025 г.
# Сайт: jinqians.com
# Описание: Этот скрипт предназначен для установки, удаления, просмотра и обновления прокси-сервера Snell
# =========================================

# Определение цветовых кодов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Текущий номер версии
current_version="4.6"

# Глобальная переменная: выбранная версия Snell
SNELL_VERSION_CHOICE=""
SNELL_VERSION=""

# === Новое: функция выбора версии ===
# Выбор версии Snell
select_snell_version() {
    echo -e "${CYAN}Пожалуйста, выберите версию Snell для установки:${RESET}"
    echo -e "${GREEN}1.${RESET} Snell v4"
    echo -e "${GREEN}2.${RESET} Snell v5"
    
    while true; do
        read -rp "请输入选项 [1-2]: " version_choice
        case "$version_choice" in
            1)
                SNELL_VERSION_CHOICE="v4"
                echo -e "${GREEN}Вы выбрали Snell v4${RESET}"
                break
                ;;
            2)
                SNELL_VERSION_CHOICE="v5"
                echo -e "${GREEN}Вы выбрали Snell v5${RESET}"
                break
                ;;
            *)
                echo -e "${RED}Пожалуйста, введите корректный вариант [1-2]${RESET}"
                ;;
        esac
    done
}

# Получить последнюю версию Snell v4
get_latest_snell_v4_version() {
    latest_version=$(curl -s https://manual.nssurge.com/others/snell.html | grep -oP 'snell-server-v\K4\.[0-9]+\.[0-9]+' | head -n 1)
    if [ -z "$latest_version" ]; then
        latest_version=$(curl -s https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell | grep -oP 'snell-server-v\K4\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    if [ -n "$latest_version" ]; then
        echo "v${latest_version}"
    else
        echo "v4.1.1"
    fi
}

# Получить последнюю версию Snell v5
get_latest_snell_v5_version() {
    # Сначала получить beta-версию
    v5_beta=$(curl -s https://manual.nssurge.com/others/snell.html | grep -oP 'snell-server-v\K5\.[0-9]+\.[0-9]+b[0-9]+' | head -n 1)
    if [ -z "$v5_beta" ]; then
        v5_beta=$(curl -s https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell | grep -oP 'snell-server-v\K5\.[0-9]+\.[0-9]+b[0-9]+' | head -n 1)
    fi
    if [ -n "$v5_beta" ]; then
        echo "v${v5_beta}"
        return
    fi
    # Затем получить стабильную версию, исключая beta (с буквой b)
    v5_release=$(curl -s https://manual.nssurge.com/others/snell.html | grep -oP 'snell-server-v\K5\.[0-9]+\.[0-9]+[a-z0-9]*' | grep -v b | head -n 1)
    if [ -z "$v5_release" ]; then
        v5_release=$(curl -s https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell | grep -oP 'snell-server-v\K5\.[0-9]+\.[0-9]+[a-z0-9]*' | grep -v b | head -n 1)
    fi
    if [ -n "$v5_release" ]; then
        echo "v${v5_release}"
    else
        echo "v5.0.0"
    fi
}

# Получить последнюю версию Snell (в зависимости от выбранной версии)
get_latest_snell_version() {
    if [ "$SNELL_VERSION_CHOICE" = "v5" ]; then
        SNELL_VERSION=$(get_latest_snell_v5_version)
    else
        SNELL_VERSION=$(get_latest_snell_v4_version)
    fi
}

# Получить URL для загрузки Snell
get_snell_download_url() {
    local version=$1
    local arch=$(uname -m)
    
    if [ "$version" = "v5" ]; then
        # Для версии v5 автоматически формируется ссылка на загрузку
        case ${arch} in
            "x86_64"|"amd64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip"
                ;;
            "i386"|"i686")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-i386.zip"
                ;;
            "aarch64"|"arm64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-aarch64.zip"
                ;;
            "armv7l"|"armv7")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-armv7l.zip"
                ;;
            *)
                echo -e "${RED}Неподдерживаемая архитектура: ${arch}${RESET}"
                exit 1
                ;;
        esac
    else
        # Для версии v4 также используется формат zip
        case ${arch} in
            "x86_64"|"amd64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip"
                ;;
            "i386"|"i686")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-i386.zip"
                ;;
            "aarch64"|"arm64")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-aarch64.zip"
                ;;
            "armv7l"|"armv7")
                echo "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-armv7l.zip"
                ;;
            *)
                echo -e "${RED}Неподдерживаемая архитектура: ${arch}${RESET}"
                exit 1
                ;;
        esac
    fi
}

# Генерация конфигурации в формате Surge
generate_surge_config() {
    local ip_addr=$1
    local port=$2
    local psk=$3
    local version=$4
    local country=$5
    local installed_version=$6   # Новый параметр

    if [ "$installed_version" = "v5" ]; then
        # Для версии v5 выводятся конфигурации как для v4, так и для v5
        echo -e "${GREEN}${country} = snell, ${ip_addr}, ${port}, psk = ${psk}, version = 4, reuse = true, tfo = true${RESET}"
        echo -e "${GREEN}${country} = snell, ${ip_addr}, ${port}, psk = ${psk}, version = 5, reuse = true, tfo = true${RESET}"
    else
        # Для версии v4 выводится только конфигурация v4
        echo -e "${GREEN}${country} = snell, ${ip_addr}, ${port}, psk = ${psk}, version = 4, reuse = true, tfo = true${RESET}"
    fi
}

# Определить текущую установленную версию Snell
detect_installed_snell_version() {
    if command -v snell-server &> /dev/null; then
        # Попытка получить информацию о версии
        local version_output=$(snell-server --v 2>&1)
        if echo "$version_output" | grep -q "v5"; then
            echo "v5"
        else
            echo "v4"
        fi
    else
        echo "unknown"
    fi
}

# === Новое: функции резервного копирования и восстановления конфигурации ===
# Резервное копирование конфигурации Snell
backup_snell_config() {
    local backup_dir="/etc/snell/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -a /etc/snell/users/*.conf "$backup_dir"/ 2>/dev/null
    echo "$backup_dir"
}

# Восстановление конфигурации Snell
restore_snell_config() {
    local backup_dir="$1"
    if [ -d "$backup_dir" ]; then
        cp -a "$backup_dir"/*.conf /etc/snell/users/
        echo -e "${GREEN}Конфигурация восстановлена из резервной копии.${RESET}"
    else
        echo -e "${RED}Резервная директория не найдена, восстановление невозможно.${RESET}"
    fi
}

# Проверка, установлен ли bc
check_bc() {
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}bc не обнаружен, выполняется установка...${RESET}"
        # Установка bc в зависимости от типа системы
        if [ -x "$(command -v apt)" ]; then
            wait_for_apt
            apt update && apt install -y bc
        elif [ -x "$(command -v yum)" ]; then
            yum install -y bc
        else
            echo -e "${RED}Неизвестный пакетный менеджер. Не удалось установить bc. Установите вручную.${RESET}"
            exit 1
        fi
    fi
}

# Проверка, установлен ли curl
check_curl() {
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}curl не обнаружен, выполняется установка...${RESET}"
        if [ -x "$(command -v apt)" ]; then
            wait_for_apt
            apt update && apt install -y curl
        elif [ -x "$(command -v yum)" ]; then
            yum install -y curl
        else
            echo -e "${RED}Неизвестный пакетный менеджер. Не удалось установить curl. Установите вручную.${RESET}"
            exit 1
        fi
    fi
}

# Определение системных путей
INSTALL_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
SNELL_CONF_DIR="/etc/snell"
SNELL_CONF_FILE="${SNELL_CONF_DIR}/users/snell-main.conf"
SYSTEMD_SERVICE_FILE="${SYSTEMD_DIR}/snell.service"

# Старые пути к конфигурационным файлам (для проверки совместимости)
OLD_SNELL_CONF_FILE="${SNELL_CONF_DIR}/snell-server.conf"
OLD_SYSTEMD_SERVICE_FILE="/lib/systemd/system/snell.service"

# Проверка и миграция старой конфигурации
check_and_migrate_config() {
    local need_migration=false
    local old_files_exist=false

    # Проверка существования старых конфигурационных файлов
    if [ -f "$OLD_SNELL_CONF_FILE" ] || [ -f "$OLD_SYSTEMD_SERVICE_FILE" ]; then
        old_files_exist=true
        echo -e "\n${YELLOW}Обнаружены конфигурационные файлы старой версии Snell${RESET}"
        echo -e "Расположение старых конфигураций:"
        [ -f "$OLD_SNELL_CONF_FILE" ] && echo -e "- Конфигурационный файл: ${OLD_SNELL_CONF_FILE}"
        [ -f "$OLD_SYSTEMD_SERVICE_FILE" ] && echo -e "- Файл службы: ${OLD_SYSTEMD_SERVICE_FILE}"
        
        # Проверка существования пользовательского каталога
        if [ ! -d "${SNELL_CONF_DIR}/users" ]; then
            need_migration=true
            mkdir -p "${SNELL_CONF_DIR}/users"
            # Установка корректных прав на каталог
            chown -R nobody:nogroup "${SNELL_CONF_DIR}"
            chmod -R 755 "${SNELL_CONF_DIR}"
        fi
    fi

    # Если требуется миграция, спросить у пользователя
    if [ "$old_files_exist" = true ]; then
        echo -e "\n${YELLOW}Хотите перенести старые конфигурационные файлы? [y/N]${RESET}"
        read -r choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            echo -e "${CYAN}Начинается перенос конфигурационных файлов...${RESET}"
            
            # Остановить службу
            systemctl stop snell 2>/dev/null
            
            # Перенос конфигурационного файла
            if [ -f "$OLD_SNELL_CONF_FILE" ]; then
                cp "$OLD_SNELL_CONF_FILE" "${SNELL_CONF_FILE}"
                # Установить правильные права на файл
                chown nobody:nogroup "${SNELL_CONF_FILE}"
                chmod 644 "${SNELL_CONF_FILE}"
                echo -e "${GREEN}Конфигурационный файл перенесён${RESET}"
            fi
            
            # Перенос файла службы
            if [ -f "$OLD_SYSTEMD_SERVICE_FILE" ]; then
                # Обновить путь к конфигурационному файлу в службе
                sed -e "s|${OLD_SNELL_CONF_FILE}|${SNELL_CONF_FILE}|g" "$OLD_SYSTEMD_SERVICE_FILE" > "$SYSTEMD_SERVICE_FILE"
                chmod 644 "$SYSTEMD_SERVICE_FILE"
                echo -e "${GREEN}Файл службы перенесён${RESET}"
            fi
            
            # Спросить, нужно ли удалить старые файлы
            echo -e "${YELLOW}Удалить старые конфигурационные файлы? [y/N]${RESET}"
            read -r del_choice
            if [[ "$del_choice" == "y" || "$del_choice" == "Y" ]]; then
                [ -f "$OLD_SNELL_CONF_FILE" ] && rm -f "$OLD_SNELL_CONF_FILE"
                [ -f "$OLD_SYSTEMD_SERVICE_FILE" ] && rm -f "$OLD_SYSTEMD_SERVICE_FILE"
                echo -e "${GREEN}Старые конфигурационные файлы удалены${RESET}"
            fi
            
            # Перезапустить службу
            systemctl daemon-reload
            systemctl start snell
            
            # Проверка состояния службы
            if systemctl is-active --quiet snell; then
                echo -e "${GREEN}Миграция завершена, служба успешно запущена${RESET}"
            else
                echo -e "${RED}Внимание: не удалось запустить службу. Проверьте конфигурационный файл и права доступа.${RESET}"
                systemctl status snell
            fi
        else
            echo -e "${YELLOW}Миграция конфигурации пропущена${RESET}"
        fi
    fi
}

# Автоматическое обновление скрипта
auto_update_script() {
    echo -e "${CYAN}Проверка обновлений скрипта...${RESET}"
    
    # Создание временного файла
    TMP_SCRIPT=$(mktemp)
    
    # Загрузка последней версии
    if curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -o "$TMP_SCRIPT"; then
        # Получить номер новой версии
        new_version=$(grep "current_version=" "$TMP_SCRIPT" | cut -d'"' -f2)
        
        # Сравнение версий
        if [ "$new_version" != "$current_version" ]; then
            echo -e "${GREEN}Обнаружена новая версия: ${new_version}${RESET}"
            echo -e "${YELLOW}Текущая версия: ${current_version}${RESET}"
            
            # Резервное копирование текущего скрипта
            cp "$0" "${0}.backup"
            
            # Обновление скрипта
            mv "$TMP_SCRIPT" "$0"
            chmod +x "$0"
            
            echo -e "${GREEN}Скрипт обновлён до последней версии${RESET}"
            echo -e "${YELLOW}Оригинальный скрипт сохранён как: ${0}.backup${RESET}"
            
            # Подсказка перезапустить скрипт
            echo -e "${CYAN}Пожалуйста, перезапустите скрипт для использования новой версии${RESET}"
            exit 0
        else
            echo -e "${GREEN}Установлена последняя версия скрипта (${current_version})${RESET}"
            rm -f "$TMP_SCRIPT"
        fi
    else
        echo -e "${RED}Не удалось проверить обновления. Проверьте подключение к сети.${RESET}"
        rm -f "$TMP_SCRIPT"
    fi
}

# Ожидание завершения других процессов apt
wait_for_apt() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        echo -e "${YELLOW}Ожидание завершения других процессов apt...${RESET}"
        sleep 1
    done
}

# Проверка, запущен ли скрипт с правами root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Пожалуйста, запустите этот скрипт от имени root.${RESET}"
        exit 1
    fi
}
check_root

# Проверка, установлен ли jq
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq не обнаружен, выполняется установка...${RESET}"
        # Установка jq в зависимости от типа системы
        if [ -x "$(command -v apt)" ]; then
            wait_for_apt
            apt update && apt install -y jq
        elif [ -x "$(command -v yum)" ]; then
            yum install -y jq
        else
            echo -e "${RED}Неизвестный пакетный менеджер. Не удалось установить jq. Установите вручную.${RESET}"
            exit 1
        fi
    fi
}
check_jq

# Проверка, установлен ли Snell
check_snell_installed() {
    if command -v snell-server &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Сравнение номеров версий
version_greater_equal() {
    local ver1=$1
    local ver2=$2
    
    # Удалить префикс 'v' или 'V' и привести к нижнему регистру
    ver1=$(echo "${ver1#[vV]}" | tr '[:upper:]' '[:lower:]')
    ver2=$(echo "${ver2#[vV]}" | tr '[:upper:]' '[:lower:]')
    
    # Обработка beta-версий (например: 5.0.0b1, 5.0.0b2)
    # Преобразование beta-версий в формат, пригодный для сравнения
    ver1=$(echo "$ver1" | sed 's/b\([0-9]*\)/\.999\1/g')
    ver2=$(echo "$ver2" | sed 's/b\([0-9]*\)/\.999\1/g')
    
    # Разделение версии на массив
    IFS='.' read -ra VER1 <<< "$ver1"
    IFS='.' read -ra VER2 <<< "$ver2"
    
    # Выравнивание длины массивов
    while [ ${#VER1[@]} -lt 4 ]; do
        VER1+=("0")
    done
    while [ ${#VER2[@]} -lt 4 ]; do
        VER2+=("0")
    done
    
    # Сравнение версий
    for i in {0..3}; do
        local val1=${VER1[i]:-0}
        local val2=${VER2[i]:-0}
        
        # Если числовое значение — сравниваем как числа
        if [[ "$val1" =~ ^[0-9]+$ ]] && [[ "$val2" =~ ^[0-9]+$ ]]; then
            if [ "$val1" -gt "$val2" ]; then
                return 0
            elif [ "$val1" -lt "$val2" ]; then
                return 1
            fi
        else
            # Если строка (например, beta) — сравниваем лексикографически
            if [[ "$val1" > "$val2" ]]; then
                return 0
            elif [[ "$val1" < "$val2" ]]; then
                return 1
            fi
        fi
    done
    return 0
}

# Ввод пользователем номера порта, диапазон 1–65535
get_user_port() {
    while true; do
        read -rp "Введите порт, который вы хотите использовать (1–65535): " PORT
        if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
            echo -e "${GREEN}Выбран порт: $PORT${RESET}"
            break
        else
            echo -e "${RED}Недопустимый номер порта. Введите число от 1 до 65535.${RESET}"
        fi
    done
}

# Получить системные DNS-серверы
get_system_dns() {
    # Попробовать получить DNS из resolv.conf
    if [ -f "/etc/resolv.conf" ]; then
        system_dns=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
        if [ ! -z "$system_dns" ]; then
            echo "$system_dns"
            return 0
        fi
    fi

    # Если не удалось получить из resolv.conf, использовать публичные DNS
    echo "1.1.1.1,8.8.8.8"
}

# Ввод DNS-сервера пользователем
get_dns() {
    read -rp "Введите адрес DNS-сервера (нажмите Enter, чтобы использовать системный): " custom_dns
    if [ -z "$custom_dns" ]; then
        DNS=$(get_system_dns)
        echo -e "${GREEN}Используется системный DNS-сервер: $DNS${RESET}"
    else
        DNS=$custom_dns
        echo -e "${GREEN}Используется пользовательский DNS-сервер: $DNS${RESET}"
    fi
}

# Открытие порта (через ufw и iptables)
open_port() {
    local PORT=$1
    # Проверка, установлен ли ufw
    if command -v ufw &> /dev/null; then
        echo -e "${CYAN}Открытие порта $PORT в UFW${RESET}"
        ufw allow "$PORT"/tcp
    fi

    # Проверка, установлен ли iptables
    if command -v iptables &> /dev/null; then
        echo -e "${CYAN}Открытие порта $PORT в iptables${RESET}"
        iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
        
        # Создание каталога для правил iptables (если не существует)
        if [ ! -d "/etc/iptables" ]; then
            mkdir -p /etc/iptables
        fi
        
        # Попытка сохранить правила, при неудаче — не прерывать выполнение
        iptables-save > /etc/iptables/rules.v4 || true
    fi
}

# Установка Snell
install_snell() {
    echo -e "${CYAN}Установка Snell...${RESET}"

    # Выбор версии Snell
    select_snell_version

    wait_for_apt
    apt update && apt install -y wget unzip

    get_latest_snell_version
    ARCH=$(uname -m)
    SNELL_URL=$(get_snell_download_url "$SNELL_VERSION_CHOICE")

    echo -e "${CYAN}Загрузка Snell ${SNELL_VERSION_CHOICE} (${SNELL_VERSION})...${RESET}"
    echo -e "${YELLOW}Ссылка для загрузки: ${SNELL_URL}${RESET}"
    
    # Обе версии (v4 и v5) используют zip-архив — обрабатываем одинаково
    wget ${SNELL_URL} -O snell-server.zip
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось загрузить Snell ${SNELL_VERSION_CHOICE}.${RESET}"
        exit 1
    fi

    unzip -o snell-server.zip -d ${INSTALL_DIR}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось распаковать Snell.${RESET}"
        exit 1
    fi

    rm snell-server.zip
    chmod +x ${INSTALL_DIR}/snell-server

    get_user_port  # Запрос порта у пользователя
    get_dns        # Запрос DNS-сервера у пользователя
    PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)

    # Создание каталога конфигурации пользователей
    mkdir -p ${SNELL_CONF_DIR}/users

    # Основная конфигурация пользователя будет храниться в каталоге users
    cat > ${SNELL_CONF_FILE} << EOF
[snell-server]
listen = ::0:${PORT}
psk = ${PSK}
ipv6 = true
dns = ${DNS}
EOF

    cat > ${SYSTEMD_SERVICE_FILE} << EOF
[Unit]
Description=Snell Proxy Service (Main)
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=${INSTALL_DIR}/snell-server -c ${SNELL_CONF_FILE}
AmbientCapabilities=CAP_NET_BIND_SERVICE
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=snell-server

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось перезагрузить конфигурацию systemd.${RESET}"
        exit 1
    fi

    systemctl enable snell
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось включить автозапуск Snell при загрузке.${RESET}"
        exit 1
    fi

    systemctl start snell
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось запустить службу Snell.${RESET}"
        exit 1
    fi

    # Открыть порт
    open_port "$PORT"

    # Вывод конфигурационной информации после завершения установки
    echo -e "\n${GREEN}Установка завершена! Вот ваша конфигурация:${RESET}"
    echo -e "${CYAN}--------------------------------${RESET}"
    echo -e "${YELLOW}Порт прослушивания: ${PORT}${RESET}"
    echo -e "${YELLOW}PSK-ключ: ${PSK}${RESET}"
    echo -e "${YELLOW}IPv6: true${RESET}"
    echo -e "${YELLOW}DNS-сервер: ${DNS}${RESET}"
    echo -e "${CYAN}--------------------------------${RESET}"

    # Получение и отображение IP-адресов сервера
    echo -e "\n${GREEN}Информация об IP-адресе сервера:${RESET}"
    
    # Получить IPv4-адрес
    IPV4_ADDR=$(curl -s4 https://api.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$IPV4_ADDR" ]; then
        IP_COUNTRY_IPV4=$(curl -s http://ipinfo.io/${IPV4_ADDR}/country)
        echo -e "${GREEN}IPv4-адрес: ${RESET}${IPV4_ADDR} ${GREEN}Страна: ${RESET}${IP_COUNTRY_IPV4}"
    fi
    
    # Получить IPv6-адрес
    IPV6_ADDR=$(curl -s6 https://api64.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$IPV6_ADDR" ]; then
        IP_COUNTRY_IPV6=$(curl -s https://ipapi.co/${IPV6_ADDR}/country/)
        echo -e "${GREEN}IPv6-адрес: ${RESET}${IPV6_ADDR} ${GREEN}Страна: ${RESET}${IP_COUNTRY_IPV6}"
    fi

    # Вывод конфигурации в формате Surge
    echo -e "\n${GREEN}Формат конфигурации для Surge:${RESET}"
    local installed_version=$(detect_installed_snell_version)
    if [ ! -z "$IPV4_ADDR" ]; then
        generate_surge_config "$IPV4_ADDR" "$PORT" "$PSK" "$SNELL_VERSION_CHOICE" "$IP_COUNTRY_IPV4" "$installed_version"
    fi
    
    if [ ! -z "$IPV6_ADDR" ]; then
        generate_surge_config "$IPV6_ADDR" "$PORT" "$PSK" "$SNELL_VERSION_CHOICE" "$IP_COUNTRY_IPV6" "$installed_version"
    fi


    # Создание управляющего скрипта
    echo -e "${CYAN}Установка управляющего скрипта...${RESET}"
    
    # Убедиться, что целевой каталог существует
    mkdir -p /usr/local/bin
    
    # Создание управляющего скрипта
    cat > /usr/local/bin/snell << 'EOFSCRIPT'
#!/bin/bash

# Определение цветовых кодов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Проверка прав root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Пожалуйста, запустите этот скрипт от имени root${RESET}"
    exit 1
fi

# Загрузка и выполнение последней версии скрипта
echo -e "${CYAN}Получение последней версии управляющего скрипта...${RESET}"
TMP_SCRIPT=$(mktemp)
if curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -o "$TMP_SCRIPT"; then
    bash "$TMP_SCRIPT"
    rm -f "$TMP_SCRIPT"
else
    echo -e "${RED}Не удалось загрузить скрипт. Проверьте подключение к сети.${RESET}"
    rm -f "$TMP_SCRIPT"
    exit 1
fi
EOFSCRIPT

    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/snell
        if [ $? -eq 0 ]; then
            echo -e "\n${GREEN}Управляющий скрипт успешно установлен!${RESET}"
            echo -e "${YELLOW}Вы можете ввести 'snell' в терминале для запуска меню управления.${RESET}"
            echo -e "${YELLOW}Внимание: необходимо запускать через sudo snell или от имени root.${RESET}\n"
        else
            echo -e "\n${RED}Не удалось задать права на выполнение для скрипта.${RESET}"
            echo -e "${YELLOW}Вы можете управлять Snell, запуская исходный скрипт вручную.${RESET}\n"
        fi
    else
        echo -e "\n${RED}Не удалось создать управляющий скрипт.${RESET}"
        echo -e "${YELLOW}Вы можете управлять Snell, запуская исходный скрипт вручную.${RESET}\n"
    fi
}

# Только обновить бинарный файл Snell без перезаписи конфигурации
update_snell_binary() {
    echo -e "${CYAN}=============== Обновление Snell ===============${RESET}"
    echo -e "${YELLOW}Внимание: это обновление, а не переустановка${RESET}"
    echo -e "${GREEN}✓ Все существующие конфигурации будут сохранены${RESET}"
    echo -e "${GREEN}✓ Порт, пароль и пользовательские настройки не изменятся${RESET}"
    echo -e "${GREEN}✓ Служба будет автоматически перезапущена${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
    
    echo -e "${CYAN}Создание резервной копии текущей конфигурации...${RESET}"
    local backup_dir
    backup_dir=$(backup_snell_config)
    echo -e "${GREEN}Конфигурация сохранена в: $backup_dir${RESET}"

    echo -e "${CYAN}Обновление бинарного файла Snell...${RESET}"
    
    # Получение последней информации о версии (уже определена в check_snell_update)
    get_latest_snell_version
    ARCH=$(uname -m)
    SNELL_URL=$(get_snell_download_url "$SNELL_VERSION_CHOICE")

    echo -e "${CYAN}Загрузка Snell ${SNELL_VERSION_CHOICE} (${SNELL_VERSION})...${RESET}"
    
    # Обе версии (v4 и v5) используют zip, обрабатываем одинаково
    wget ${SNELL_URL} -O snell-server.zip
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось загрузить Snell ${SNELL_VERSION_CHOICE}.${RESET}"
        restore_snell_config "$backup_dir"
        exit 1
    fi

    echo -e "${CYAN}Замена бинарного файла Snell...${RESET}"
    unzip -o snell-server.zip -d ${INSTALL_DIR}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка распаковки Snell.${RESET}"
        restore_snell_config "$backup_dir"
        exit 1
    fi

    rm snell-server.zip
    chmod +x ${INSTALL_DIR}/snell-server

    echo -e "${CYAN}Перезапуск службы Snell...${RESET}"
    # Перезапуск основной службы
    systemctl restart snell
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось перезапустить основную службу, пробуем восстановить конфигурацию...${RESET}"
        restore_snell_config "$backup_dir"
        systemctl restart snell
    fi

    # Перезапуск всех дополнительных пользовательских служб
    if [ -d "${SNELL_CONF_DIR}/users" ]; then
        for user_conf in "${SNELL_CONF_DIR}/users"/*; do
            if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
                local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
                if [ ! -z "$port" ]; then
                    systemctl restart "snell-${port}" 2>/dev/null
                fi
            fi
        done
    fi

    echo -e "${CYAN}===============================================${RESET}"
    echo -e "${GREEN}✅ Snell успешно обновлён!${RESET}"
    echo -e "${GREEN}✓ Обновлённая версия: ${SNELL_VERSION_CHOICE} (${SNELL_VERSION})${RESET}"
    echo -e "${GREEN}✓ Все конфигурации сохранены${RESET}"
    echo -e "${GREEN}✓ Службы перезапущены${RESET}"
    echo -e "${YELLOW}Каталог с резервной копией конфигурации: $backup_dir${RESET}"
    echo -e "${CYAN}===============================================${RESET}"
}

# Удаление Snell
uninstall_snell() {
    echo -e "${CYAN}Удаление Snell...${RESET}"

    # Остановить и отключить основную службу
    systemctl stop snell
    systemctl disable snell

    # Остановить и отключить все дополнительные пользовательские службы
    if [ -d "${SNELL_CONF_DIR}/users" ]; then
        for user_conf in "${SNELL_CONF_DIR}/users"/*; do
            if [ -f "$user_conf" ]; then
                local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
                if [ ! -z "$port" ]; then
                    echo -e "${YELLOW}Остановка пользовательской службы (порт: $port)${RESET}"
                    systemctl stop "snell-${port}" 2>/dev/null
                    systemctl disable "snell-${port}" 2>/dev/null
                    rm -f "${SYSTEMD_DIR}/snell-${port}.service"
                fi
            fi
        done
    fi

    # Удаление файла службы
    rm -f /lib/systemd/system/snell.service

    # Удаление исполняемого файла и каталога конфигурации
    rm -f /usr/local/bin/snell-server
    rm -rf ${SNELL_CONF_DIR}
    rm -f /usr/local/bin/snell  # Удаление управляющего скрипта

    # Перезагрузка конфигурации systemd
    systemctl daemon-reload

    echo -e "${GREEN}Snell и все связанные с ним пользовательские конфигурации успешно удалены${RESET}"
}

# Перезапуск Snell
restart_snell() {
    echo -e "${YELLOW}Перезапуск всех служб Snell...${RESET}"
    
    # Перезапуск основной службы
    systemctl restart snell
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Основная служба Snell успешно перезапущена.${RESET}"
    else
        echo -e "${RED}Не удалось перезапустить основную службу Snell.${RESET}"
    fi

    # Перезапуск всех пользовательских служб
    if [ -d "${SNELL_CONF_DIR}/users" ]; then
        for user_conf in "${SNELL_CONF_DIR}/users"/*; do
            if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
                local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
                if [ ! -z "$port" ]; then
                    echo -e "${YELLOW}Перезапуск пользовательской службы (порт: $port)${RESET}"
                    systemctl restart "snell-${port}" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Пользовательская служба (порт: $port) успешно перезапущена.${RESET}"
                    else
                        echo -e "${RED}Не удалось перезапустить пользовательскую службу (порт: $port).${RESET}"
                    fi
                fi
            fi
        done
    fi
}
# Проверка состояния службы и вывод информации
check_and_show_status() {
    echo -e "\n${CYAN}=============== Проверка состояния служб ===============${RESET}"
    
    # Проверка, установлен ли Snell
    if command -v snell-server &> /dev/null; then
        # Инициализация счётчиков и переменных для ресурсов
        local user_count=0
        local running_count=0
        local total_snell_memory=0
        local total_snell_cpu=0

        # Проверка состояния основной службы
        if systemctl is-active snell &> /dev/null; then
            user_count=$((user_count + 1))
            running_count=$((running_count + 1))
            
            # Получение информации о потреблении ресурсов основной службой
            local main_pid=$(systemctl show -p MainPID snell | cut -d'=' -f2)
            if [ ! -z "$main_pid" ] && [ "$main_pid" != "0" ]; then
                local mem=$(ps -o rss= -p $main_pid 2>/dev/null)
                local cpu=$(ps -o %cpu= -p $main_pid 2>/dev/null)
                if [ ! -z "$mem" ]; then
                    total_snell_memory=$((total_snell_memory + mem))
                fi
                if [ ! -z "$cpu" ]; then
                    total_snell_cpu=$(echo "$total_snell_cpu + $cpu" | bc -l)
                fi
            fi
        else
            user_count=$((user_count + 1))
        fi

        # Проверка состояния дополнительных пользовательских служб
        if [ -d "${SNELL_CONF_DIR}/users" ]; then
            for user_conf in "${SNELL_CONF_DIR}/users"/*; do
                if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
                    local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
                    if [ ! -z "$port" ]; then
                        user_count=$((user_count + 1))
                        if systemctl is-active --quiet "snell-${port}"; then
                            running_count=$((running_count + 1))

                            # Получение информации о потреблении ресурсов пользователем
                            local user_pid=$(systemctl show -p MainPID "snell-${port}" | cut -d'=' -f2)
                            if [ ! -z "$user_pid" ] && [ "$user_pid" != "0" ]; then
                                local mem=$(ps -o rss= -p $user_pid 2>/dev/null)
                                local cpu=$(ps -o %cpu= -p $user_pid 2>/dev/null)
                                if [ ! -z "$mem" ]; then
                                    total_snell_memory=$((total_snell_memory + mem))
                                fi
                                if [ ! -z "$cpu" ]; then
                                    total_snell_cpu=$(echo "$total_snell_cpu + $cpu" | bc -l)
                                fi
                            fi
                        fi
                    fi
                fi
            done
        fi
        
        # Вывод состояния Snell
        local total_snell_memory_mb=$(echo "scale=2; $total_snell_memory/1024" | bc)
        printf "${GREEN}Snell установлен${RESET}  ${YELLOW}CPU: %.2f%%${RESET}  ${YELLOW}Память: %.2f MB${RESET}  ${GREEN}Активных: ${running_count}/${user_count}${RESET}\n" "$total_snell_cpu" "$total_snell_memory_mb"
    else
        echo -e "${YELLOW}Snell не установлен${RESET}"
    fi

    # Проверка состояния ShadowTLS
    if [ -f "/usr/local/bin/shadow-tls" ]; then
        # Инициализация счётчиков и ресурсов для ShadowTLS
        local stls_total=0
        local stls_running=0
        local total_stls_memory=0
        local total_stls_cpu=0
        declare -A processed_ports

        # Поиск служб ShadowTLS, связанных со Snell
        local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null | sort -u)
        if [ ! -z "$snell_services" ]; then
            while IFS= read -r service_file; do
                local port=$(basename "$service_file" | sed 's/shadowtls-snell-\([0-9]*\)\.service/\1/')

                # Проверка: порт уже обработан?
                if [ -z "${processed_ports[$port]}" ]; then
                    processed_ports[$port]=1
                    stls_total=$((stls_total + 1))
                    if systemctl is-active "shadowtls-snell-${port}" &> /dev/null; then
                        stls_running=$((stls_running + 1))

                        # Получение данных о потреблении ресурсов ShadowTLS
                        local stls_pid=$(systemctl show -p MainPID "shadowtls-snell-${port}" | cut -d'=' -f2)
                        if [ ! -z "$stls_pid" ] && [ "$stls_pid" != "0" ]; then
                            local mem=$(ps -o rss= -p $stls_pid 2>/dev/null)
                            local cpu=$(ps -o %cpu= -p $stls_pid 2>/dev/null)
                            if [ ! -z "$mem" ]; then
                                total_stls_memory=$((total_stls_memory + mem))
                            fi
                            if [ ! -z "$cpu" ]; then
                                total_stls_cpu=$(echo "$total_stls_cpu + $cpu" | bc -l)
                            fi
                        fi
                    fi
                fi
            done <<< "$snell_services"
        fi

        # Вывод состояния ShadowTLS
        if [ $stls_total -gt 0 ]; then
            local total_stls_memory_mb=$(echo "scale=2; $total_stls_memory/1024" | bc)
            printf "${GREEN}ShadowTLS установлен${RESET}  ${YELLOW}CPU: %.2f%%${RESET}  ${YELLOW}Память: %.2f MB${RESET}  ${GREEN}Активных: ${stls_running}/${stls_total}${RESET}\n" "$total_stls_cpu" "$total_stls_memory_mb"
        else
            echo -e "${YELLOW}ShadowTLS не запущен${RESET}"
        fi
    else
        echo -e "${YELLOW}ShadowTLS не установлен${RESET}"
    fi

    echo -e "${CYAN}============================================${RESET}\n"
}

# Просмотр конфигурации
view_snell_config() {
    echo -e "${GREEN}Информация о конфигурации Snell:${RESET}"
    echo -e "${CYAN}================================${RESET}"
    
    # Определение установленной версии Snell
    local installed_version=$(detect_installed_snell_version)
    if [ "$installed_version" != "unknown" ]; then
        echo -e "${YELLOW}Установленная версия: Snell ${installed_version}${RESET}"
    fi

    # Получение IPv4-адреса
    IPV4_ADDR=$(curl -s4 https://api.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$IPV4_ADDR" ]; then
        IP_COUNTRY_IPV4=$(curl -s http://ipinfo.io/${IPV4_ADDR}/country)
        echo -e "${GREEN}IPv4-адрес: ${RESET}${IPV4_ADDR} ${GREEN}Страна: ${RESET}${IP_COUNTRY_IPV4}"
    fi

    # Получение IPv6-адреса
    IPV6_ADDR=$(curl -s6 https://api64.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$IPV6_ADDR" ]; then
        IP_COUNTRY_IPV6=$(curl -s https://ipapi.co/${IPV6_ADDR}/country/)
        echo -e "${GREEN}IPv6-адрес: ${RESET}${IPV6_ADDR} ${GREEN}Страна: ${RESET}${IP_COUNTRY_IPV6}"
    fi

    # Проверка, удалось ли получить хотя бы один IP-адрес
    if [ -z "$IPV4_ADDR" ] && [ -z "$IPV6_ADDR" ]; then
        echo -e "${RED}Не удалось получить публичный IP-адрес. Пожалуйста, проверьте сетевое соединение.${RESET}"
        return
    fi

    echo -e "\n${YELLOW}=== Список конфигураций пользователей ===${RESET}"
    
    # Отображение конфигурации основного пользователя
    local main_conf="${SNELL_CONF_DIR}/users/snell-main.conf"
    if [ -f "$main_conf" ]; then
        echo -e "\n${GREEN}Конфигурация основного пользователя:${RESET}"
        local main_port=$(grep -E '^listen' "$main_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
        local main_psk=$(grep -E '^psk' "$main_conf" | awk -F'=' '{print $2}' | tr -d ' ')
        local main_ipv6=$(grep -E '^ipv6' "$main_conf" | awk -F'=' '{print $2}' | tr -d ' ')
        local main_dns=$(grep -E '^dns' "$main_conf" | awk -F'=' '{print $2}' | tr -d ' ')

        echo -e "${YELLOW}Порт: ${main_port}${RESET}"
        echo -e "${YELLOW}PSK: ${main_psk}${RESET}"
        echo -e "${YELLOW}IPv6: ${main_ipv6}${RESET}"
        echo -e "${YELLOW}DNS: ${main_dns}${RESET}"

        echo -e "\n${GREEN}Формат конфигурации для Surge:${RESET}"
        if [ ! -z "$IPV4_ADDR" ]; then
            generate_surge_config "$IPV4_ADDR" "$main_port" "$main_psk" "$installed_version" "$IP_COUNTRY_IPV4" "$installed_version"
        fi
        if [ ! -z "$IPV6_ADDR" ]; then
            generate_surge_config "$IPV6_ADDR" "$main_port" "$main_psk" "$installed_version" "$IP_COUNTRY_IPV6" "$installed_version"
        fi
    fi
    
    # Отображение конфигураций других пользователей
    if [ -d "${SNELL_CONF_DIR}/users" ]; then
        for user_conf in "${SNELL_CONF_DIR}/users"/*; do
            if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
                local user_port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
                local user_psk=$(grep -E '^psk' "$user_conf" | awk -F'=' '{print $2}' | tr -d ' ')
                local user_ipv6=$(grep -E '^ipv6' "$user_conf" | awk -F'=' '{print $2}' | tr -d ' ')
                local user_dns=$(grep -E '^dns' "$user_conf" | awk -F'=' '{print $2}' | tr -d ' ')

                echo -e "\n${GREEN}Конфигурация пользователя (порт: ${user_port}):${RESET}"
                echo -e "${YELLOW}PSK: ${user_psk}${RESET}"
                echo -e "${YELLOW}IPv6: ${user_ipv6}${RESET}"
                echo -e "${YELLOW}DNS: ${user_dns}${RESET}"

                echo -e "\n${GREEN}Формат конфигурации для Surge:${RESET}"
                if [ ! -z "$IPV4_ADDR" ]; then
                    generate_surge_config "$IPV4_ADDR" "$user_port" "$user_psk" "$installed_version" "$IP_COUNTRY_IPV4" "$installed_version"
                fi
                if [ ! -z "$IPV6_ADDR" ]; then
                    generate_surge_config "$IPV6_ADDR" "$user_port" "$user_psk" "$installed_version" "$IP_COUNTRY_IPV6" "$installed_version"
                fi
            fi
        done
    fi
    
    # Если ShadowTLS установлен — отобразить комбинированную конфигурацию
    local snell_version=$(detect_installed_snell_version)
    local snell_services=$(find /etc/systemd/system -name "shadowtls-snell-*.service" 2>/dev/null | sort -u)
    if [ ! -z "$snell_services" ]; then
        echo -e "\n${YELLOW}=== Комбинированная конфигурация ShadowTLS ===${RESET}"
        declare -A processed_ports
        while IFS= read -r service_file; do
            local exec_line=$(grep "ExecStart=" "$service_file")
            local stls_port=$(echo "$exec_line" | grep -oP '(?<=--listen ::0:)\d+')
            local stls_password=$(echo "$exec_line" | grep -oP '(?<=--password )[^ ]+')
            local stls_domain=$(echo "$exec_line" | grep -oP '(?<=--tls )[^ ]+')
            local snell_port=$(echo "$exec_line" | grep -oP '(?<=--server 127.0.0.1:)\d+')
            # Поиск psk
            local psk=""
            if [ -f "${SNELL_CONF_DIR}/users/snell-${snell_port}.conf" ]; then
                psk=$(grep -E '^psk' "${SNELL_CONF_DIR}/users/snell-${snell_port}.conf" | awk -F'=' '{print $2}' | tr -d ' ')
            elif [ -f "${SNELL_CONF_DIR}/users/snell-main.conf" ] && [ "$snell_port" = "$(get_snell_port)" ]; then
                psk=$(grep -E '^psk' "${SNELL_CONF_DIR}/users/snell-main.conf" | awk -F'=' '{print $2}' | tr -d ' ')
            fi
            # Исключить дубликаты
            if [ -z "$snell_port" ] || [ -z "$psk" ] || [ -n "${processed_ports[$snell_port]}" ]; then
                continue
            fi
            processed_ports[$snell_port]=1
            if [ "$snell_port" = "$(get_snell_port)" ]; then
                echo -e "\n${GREEN}Основной пользователь — ShadowTLS конфигурация:${RESET}"
            else
                echo -e "\n${GREEN}Пользовательская ShadowTLS конфигурация (порт: ${snell_port}):${RESET}"
            fi
            echo -e "  - Порт Snell: ${snell_port}"
            echo -e "  - PSK: ${psk}"
            echo -e "  - Порт ShadowTLS: ${stls_port}"
            echo -e "  - Пароль ShadowTLS: ${stls_password}"
            echo -e "  - SNI для ShadowTLS: ${stls_domain}"
            echo -e "  - Версия: 3"
            echo -e "\n${GREEN}Формат конфигурации для Surge:${RESET}"
            if [ ! -z "$IPV4_ADDR" ]; then
                if [ "$snell_version" = "v5" ]; then
                    echo -e "${GREEN}${IP_COUNTRY_IPV4} = snell, ${IPV4_ADDR}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                    echo -e "${GREEN}${IP_COUNTRY_IPV4} = snell, ${IPV4_ADDR}, ${stls_port}, psk = ${psk}, version = 5, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                else
                    echo -e "${GREEN}${IP_COUNTRY_IPV4} = snell, ${IPV4_ADDR}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                fi
            fi
            if [ ! -z "$IPV6_ADDR" ]; then
                if [ "$snell_version" = "v5" ]; then
                    echo -e "${GREEN}${IP_COUNTRY_IPV6} = snell, ${IPV6_ADDR}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                    echo -e "${GREEN}${IP_COUNTRY_IPV6} = snell, ${IPV6_ADDR}, ${stls_port}, psk = ${psk}, version = 5, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                else
                    echo -e "${GREEN}${IP_COUNTRY_IPV6} = snell, ${IPV6_ADDR}, ${stls_port}, psk = ${psk}, version = 4, reuse = true, tfo = true, shadow-tls-password = ${stls_password}, shadow-tls-sni = ${stls_domain}, shadow-tls-version = 3${RESET}"
                fi
            fi
        done <<< "$snell_services"
    fi
    
    echo -e "\n${YELLOW}Внимание:${RESET}"
    echo -e "1. Snell поддерживается только клиентом Surge"
    echo -e "2. Пожалуйста, замените адрес сервера в конфигурации на фактический IP-адрес"
    read -p "Нажмите любую клавишу, чтобы вернуться в главное меню..."
}

# Получение текущей установленной версии Snell
get_current_snell_version() {
    # Определить установленную версию Snell
    local current_installed_version=$(detect_installed_snell_version)

    if [ "$current_installed_version" = "v5" ]; then
        # Для версии v5 получить полный номер версии
        CURRENT_VERSION=$(snell-server --v 2>&1 | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+[a-z0-9]*')
        if [ -z "$CURRENT_VERSION" ]; then
            # Если не удалось получить — установить по умолчанию
            CURRENT_VERSION="v5.0.0b3"
        fi
    else
        # Для версии v4
        CURRENT_VERSION=$(snell-server --v 2>&1 | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')
        if [ -z "$CURRENT_VERSION" ]; then
            echo -e "${RED}Не удалось определить текущую версию Snell.${RESET}"
            exit 1
        fi
    fi
}

# Проверка наличия обновлений Snell
check_snell_update() {
    echo -e "\n${CYAN}=============== Проверка обновлений Snell ===============${RESET}"

    # Определение установленной версии Snell
    local current_installed_version=$(detect_installed_snell_version)
    if [ "$current_installed_version" = "unknown" ]; then
        echo -e "${RED}Не удалось определить установленную версию Snell${RESET}"
        return 1
    fi

    echo -e "${YELLOW}Установленная версия: Snell ${current_installed_version}${RESET}"
    
    # Определить стратегию обновления в зависимости от текущей версии
    if [ "$current_installed_version" = "v4" ]; then
        # Пользователь v4: предложить обновление до v5
        echo -e "\n${CYAN}Обнаружено, что вы используете Snell v4. Хотите обновиться до v5?${RESET}"
        echo -e "${YELLOW}Внимание: Snell v5 — это тестовая версия и может содержать ошибки или проблемы совместимости.${RESET}"
        echo -e "${GREEN}1.${RESET} Обновиться до Snell v5"
        echo -e "${GREEN}2.${RESET} Остаться на Snell v4 (проверить обновления v4)"
        echo -e "${GREEN}3.${RESET} Отменить обновление"

        while true; do
            read -rp "Пожалуйста, выберите [1-3]: " upgrade_choice
            case "$upgrade_choice" in
                1)
                    SNELL_VERSION_CHOICE="v5"
                    echo -e "${GREEN}Вы выбрали обновление до Snell v5${RESET}"
                    break
                    ;;
                2)
                    SNELL_VERSION_CHOICE="v4"
                    echo -e "${GREEN}Вы выбрали остаться на Snell v4${RESET}"
                    break
                    ;;
                3)
                    echo -e "${CYAN}Обновление отменено${RESET}"
                    return 0
                    ;;
                *)
                    echo -e "${RED}Введите корректный вариант [1-3]${RESET}"
                    ;;
            esac
        done
    else
        # Пользователь v5: проверка обновлений без выбора
        SNELL_VERSION_CHOICE="v5"
        echo -e "${GREEN}Вы используете Snell v5 — будет выполнена проверка обновлений для v5${RESET}"
    fi

    # Получить последнюю доступную версию
    get_latest_snell_version
    get_current_snell_version

    echo -e "${YELLOW}Текущая версия Snell: ${CURRENT_VERSION}${RESET}"
    echo -e "${YELLOW}Последняя доступная версия: ${SNELL_VERSION}${RESET}"

    # Проверка необходимости обновления
    if ! version_greater_equal "$CURRENT_VERSION" "$SNELL_VERSION"; then
        echo -e "\n${CYAN}Доступна новая версия. Информация об обновлении:${RESET}"
        echo -e "${GREEN}✓ Это обновление, а не переустановка${RESET}"
        echo -e "${GREEN}✓ Все существующие настройки будут сохранены (порт, пароль, пользователи)${RESET}"
        echo -e "${GREEN}✓ Служба будет автоматически перезапущена${RESET}"
        echo -e "${GREEN}✓ Конфигурация будет автоматически сохранена в резервную копию${RESET}"
        echo -e "${CYAN}Хотите обновить Snell? [y/N]${RESET}"
        read -r choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            update_snell_binary
        else
            echo -e "${CYAN}Обновление отменено.${RESET}"
        fi
    else
        echo -e "${GREEN}Установлена последняя версия (${CURRENT_VERSION}). Обновление не требуется.${RESET}"
    fi
}

# Получение последней версии с GitHub
get_latest_github_version() {
    local api_url="https://api.github.com/repos/jinqians/snell.sh/releases/latest"
    local response

    response=$(curl -s "$api_url")
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo -e "${RED}Не удалось получить информацию о последней версии с GitHub.${RESET}"
        return 1
    fi

    GITHUB_VERSION=$(echo "$response" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [ -z "$GITHUB_VERSION" ]; then
        echo -e "${RED}Не удалось разобрать информацию о версии с GitHub.${RESET}"
        return 1
    fi
}

# Обновление скрипта
update_script() {
    echo -e "${CYAN}Проверка обновлений скрипта...${RESET}"

    # Создание временного файла
    TMP_SCRIPT=$(mktemp)

    # Загрузка последней версии скрипта
    if curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/snell.sh -o "$TMP_SCRIPT"; then
        # Получение номера новой версии
        new_version=$(grep "current_version=" "$TMP_SCRIPT" | cut -d'"' -f2)

        if [ -z "$new_version" ]; then
            echo -e "${RED}Не удалось получить информацию о новой версии${RESET}"
            rm -f "$TMP_SCRIPT"
            return 1
        fi

        echo -e "${YELLOW}Текущая версия: ${current_version}${RESET}"
        echo -e "${YELLOW}Последняя версия: ${new_version}${RESET}"

        # Сравнение версий
        if [ "$new_version" != "$current_version" ]; then
            echo -e "${CYAN}Обновить до новой версии? [y/N]${RESET}"
            read -r choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                # Определение пути текущего скрипта
                SCRIPT_PATH=$(readlink -f "$0")

                # Резервное копирование текущей версии
                cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"

                # Обновление
                mv "$TMP_SCRIPT" "$SCRIPT_PATH"
                chmod +x "$SCRIPT_PATH"

                echo -e "${GREEN}Скрипт успешно обновлён до последней версии${RESET}"
                echo -e "${YELLOW}Резервная копия сохранена как: ${SCRIPT_PATH}.backup${RESET}"
                echo -e "${CYAN}Пожалуйста, перезапустите скрипт, чтобы применить обновление${RESET}"
                exit 0
            else
                echo -e "${YELLOW}Обновление отменено${RESET}"
                rm -f "$TMP_SCRIPT"
            fi
        else
            echo -e "${GREEN}Установлена последняя версия${RESET}"
            rm -f "$TMP_SCRIPT"
        fi
    else
        echo -e "${RED}Не удалось загрузить обновление. Проверьте подключение к сети.${RESET}"
        rm -f "$TMP_SCRIPT"
    fi
}

# Проверка установленного сервиса
check_installation() {
    local service=$1
    if systemctl list-unit-files | grep -q "^$service.service"; then
        echo -e "${GREEN}Установлен${RESET}"
    else
        echo -e "${RED}Не установлен${RESET}"
    fi
}

# Получение конфигурации ShadowTLS
get_shadowtls_config() {
    # Получить порт основного Snell
    local main_port=$(get_snell_port)
    if [ -z "$main_port" ]; then
        return 1
    fi

    # Проверка активности соответствующей службы ShadowTLS
    local service_name="shadowtls-snell-${main_port}"
    if ! systemctl is-active --quiet "$service_name"; then
        return 1
    fi

    local service_file="/etc/systemd/system/${service_name}.service"
    if [ ! -f "$service_file" ]; then
        return 1
    fi

    # Считать строку запуска из service-файла
    local exec_line=$(grep "ExecStart=" "$service_file")
    if [ -z "$exec_line" ]; then
        return 1
    fi

    # Извлечь параметры конфигурации
    local tls_domain=$(echo "$exec_line" | grep -o -- "--tls [^ ]*" | cut -d' ' -f2)
    local password=$(echo "$exec_line" | grep -o -- "--password [^ ]*" | cut -d' ' -f2)
    local listen_part=$(echo "$exec_line" | grep -o -- "--listen [^ ]*" | cut -d' ' -f2)
    local listen_port=$(echo "$listen_part" | grep -o '[0-9]*$')

    if [ -z "$tls_domain" ] || [ -z "$password" ] || [ -z "$listen_port" ]; then
        return 1
    fi

    echo "${password}|${tls_domain}|${listen_port}"
    return 0
}

# Проверка на запуск от root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Пожалуйста, запустите скрипт с правами root${RESET}"
        exit 1
    fi
}

# Первичная проверка системы
initial_check() {
    check_root
    check_curl
    check_bc
    check_and_migrate_config
    check_and_show_status
}

# Запустить первичную проверку
initial_check

# Управление несколькими пользователями
setup_multi_user() {
    echo -e "${CYAN}Запуск скрипта управления несколькими пользователями...${RESET}"
    bash <(curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/multi-user.sh)

    # Скрипт завершит выполнение и вернёт управление сюда
    echo -e "${GREEN}Операция управления пользователями завершена.${RESET}"
    sleep 1  # Краткая пауза для отображения сообщения
}

# Главное меню
show_menu() {
    clear
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${CYAN}          Скрипт управления Snell v${current_version}${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${GREEN}Автор: jinqian${RESET}"
    echo -e "${GREEN}Сайт: https://jinqians.com${RESET}"
    echo -e "${CYAN}============================================${RESET}"

    # Проверка и отображение состояния службы
    check_and_show_status

    echo -e "${YELLOW}=== Основные функции ===${RESET}"
    echo -e "${GREEN}1.${RESET} Установить Snell"
    echo -e "${GREEN}2.${RESET} Удалить Snell"
    echo -e "${GREEN}3.${RESET} Просмотр конфигурации"
    echo -e "${GREEN}4.${RESET} Перезапустить службу"

    echo -e "\n${YELLOW}=== Расширенные функции ===${RESET}"
    echo -e "${GREEN}5.${RESET} Управление ShadowTLS"
    echo -e "${GREEN}6.${RESET} Управление BBR"
    echo -e "${GREEN}7.${RESET} Многопользовательское управление"

    echo -e "\n${YELLOW}=== Системные функции ===${RESET}"
    echo -e "${GREEN}8.${RESET} Обновить Snell"
    echo -e "${GREEN}9.${RESET} Обновить скрипт"
    echo -e "${GREEN}10.${RESET} Проверить состояние службы"
    echo -e "${GREEN}0.${RESET} Выйти из скрипта"

    echo -e "${CYAN}============================================${RESET}"
    read -rp "Пожалуйста, выберите [0-10]: " num
}

# Включение BBR
setup_bbr() {
    echo -e "${CYAN}Получение и выполнение скрипта управления BBR...${RESET}"
    
    # Непосредственный запуск удалённого скрипта BBR
    bash <(curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/bbr.sh)
    
    # После выполнения скрипта автоматически вернётся сюда
    echo -e "${GREEN}Управление BBR завершено.${RESET}"
    sleep 1  # Небольшая пауза для отображения сообщения
}

# Управление ShadowTLS
setup_shadowtls() {
    echo -e "${CYAN}Запуск скрипта управления ShadowTLS...${RESET}"
    bash <(curl -sL https://raw.githubusercontent.com/jinqians/snell.sh/main/shadowtls.sh)
    
    # После выполнения скрипта автоматически вернётся сюда
    echo -e "${GREEN}Управление ShadowTLS завершено.${RESET}"
    sleep 1  # Небольшая пауза для отображения сообщения
}

# Получение порта основного пользователя Snell
get_snell_port() {
    if [ -f "${SNELL_CONF_DIR}/users/snell-main.conf" ]; then
        grep -E '^listen' "${SNELL_CONF_DIR}/users/snell-main.conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p'
    fi
}

# Получение всех конфигураций пользователей Snell
get_all_snell_users() {
    # Проверка наличия директории конфигураций пользователей
    if [ ! -d "${SNELL_CONF_DIR}/users" ]; then
        return 1
    fi

    # Сначала получить конфигурацию основного пользователя
    local main_port=""
    local main_psk=""
    if [ -f "${SNELL_CONF_DIR}/users/snell-main.conf" ]; then
        main_port=$(grep -E '^listen' "${SNELL_CONF_DIR}/users/snell-main.conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
        main_psk=$(grep -E '^psk' "${SNELL_CONF_DIR}/users/snell-main.conf" | awk -F'=' '{print $2}' | tr -d ' ')
        if [ ! -z "$main_port" ] && [ ! -z "$main_psk" ]; then
            echo "${main_port}|${main_psk}"
        fi
    fi
    
    # Получение конфигураций других пользователей
    for user_conf in "${SNELL_CONF_DIR}/users"/snell-*.conf; do
        if [ -f "$user_conf" ] && [[ "$user_conf" != *"snell-main.conf" ]]; then
            local port=$(grep -E '^listen' "$user_conf" | sed -n 's/.*::0:\([0-9]*\)/\1/p')
            local psk=$(grep -E '^psk' "$user_conf" | awk -F'=' '{print $2}' | tr -d ' ')
            if [ ! -z "$port" ] && [ ! -z "$psk" ]; then
                echo "${port}|${psk}"
            fi
        fi
    done
}

# Основной цикл
while true; do
    show_menu
    case "$num" in
        1)
            install_snell
            ;;
        2)
            uninstall_snell
            ;;
        3)
            view_snell_config
            ;;
        4)
            restart_snell
            ;;
        5)
            setup_shadowtls
            ;;
        6)
            setup_bbr
            ;;
        7)
            setup_multi_user
            ;;
        8)
            check_snell_update
            ;;
        9)
            update_script
            ;;
        10)
            check_and_show_status
            read -p "Нажмите любую клавишу для продолжения..."
            ;;
        0)
            echo -e "${GREEN}Спасибо за использование. До свидания!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Пожалуйста, введите корректный вариант [0-10]${RESET}"
            ;;
    esac
    echo -e "\n${CYAN}Нажмите любую клавишу для возврата в главное меню...${RESET}"
    read -n 1 -s -r
done