#!/bin/bash
# =========================================
# Автор: jinqians
# Дата: ноябрь 2024
# Сайт: jinqians.com
# Описание: Этот скрипт предназначен для настройки BBR
# =========================================

# Определение цветов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Проверка запуска от root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Пожалуйста, запустите этот скрипт от имени root.${RESET}"
    exit 1
fi

# Настройка системных параметров и включение BBR
configure_system_and_bbr() {
    echo -e "${YELLOW}Настройка системных параметров и BBR...${RESET}"
    
    cat > /etc/sysctl.conf << EOF
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.ip_forward = 1
net.ipv4.conf.all.route_localnet = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF

    sysctl -p

    if lsmod | grep -q tcp_bbr && sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        echo -e "${GREEN}BBR и системные параметры успешно настроены.${RESET}"
    else
        echo -e "${YELLOW}BBR или системные параметры могут потребовать перезагрузки системы для вступления в силу.${RESET}"
    fi
}

# Включение стандартного BBR
enable_bbr() {
    echo -e "${YELLOW}Включение стандартного BBR...${RESET}"
    
    # Проверка, уже включен ли BBR
    if lsmod | grep -q "^tcp_bbr" && sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        echo -e "${GREEN}BBR уже включён.${RESET}"
        return 0
    fi
    
    configure_system_and_bbr
}

# Установка XanMod BBR v3
install_xanmod_bbr() {
    echo -e "${YELLOW}Подготовка к установке ядра XanMod...${RESET}"
    
    # Проверка архитектуры
    if [ "$(uname -m)" != "x86_64" ]; then
        echo -e "${RED}Ошибка: поддерживается только архитектура x86_64${RESET}"
        return 1
    fi
    
    # Проверка системы
    if ! grep -Eqi "debian|ubuntu" /etc/os-release; then
        echo -e "${RED}Ошибка: поддерживаются только системы Debian/Ubuntu${RESET}"
        return 1
    fi
    
    # Добавление PGP-ключа
    wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
    
    # Добавление репозитория
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
    
    # Обновление списка пакетов
    apt update -y
    
    # Попытка установить последнюю версию
    echo -e "${YELLOW}Пробуем установить последнюю версию ядра...${RESET}"
    if apt install -y linux-xanmod-x64v4; then
        echo -e "${GREEN}Последняя версия ядра успешно установлена${RESET}"
    else
        echo -e "${YELLOW}Не удалось установить последнюю версию, пробуем старую...${RESET}"
        if apt install -y linux-xanmod-x64v2; then
            echo -e "${GREEN}Совместимая версия ядра успешно установлена${RESET}"
        else
            echo -e "${RED}Не удалось установить ядро${RESET}"
            return 1
        fi
    fi
    
    configure_system_and_bbr
    
    echo -e "${GREEN}Установка ядра XanMod завершена. Пожалуйста, перезагрузите систему для применения нового ядра.${RESET}"
    read -p "Перезагрузить систему сейчас? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Ручная компиляция и установка BBR v3
install_bbr3_manual() {
    echo -e "${YELLOW}Подготовка к ручной компиляции и установке BBR v3...${RESET}"
    
    # Установка зависимостей
    apt update
    apt install -y build-essential git
    
    # Клонирование исходников
    git clone -b v3 https://github.com/google/bbr.git
    cd bbr
    
    # Сборка и установка
    make
    make install
    
    configure_system_and_bbr
    
    echo -e "${GREEN}BBR v3 успешно скомпилирован и установлен${RESET}"
    read -p "Перезагрузить систему сейчас? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Главное меню
main_menu() {
    while true; do
        echo -e "\n${CYAN}Меню управления BBR${RESET}"
        echo -e "${YELLOW}1. Включить стандартный BBR${RESET}"
        echo -e "${YELLOW}2. Установить BBR v3 (версия XanMod)${RESET}"
        echo -e "${YELLOW}3. Установить BBR v3 (ручная сборка)${RESET}"
        echo -e "${YELLOW}4. Вернуться в предыдущее меню${RESET}"
        echo -e "${YELLOW}5. Выйти из скрипта${RESET}"
        read -p "Выберите действие [1-5]: " choice

        case "$choice" in
            1)
                enable_bbr
                ;;
            2)
                install_xanmod_bbr
                ;;
            3)
                install_bbr3_manual
                ;;
            4)
                return 0
                ;;
            5)
                exit 0
                ;;
            *)
                echo -e "${RED}Недопустимый выбор${RESET}"
                ;;
        esac
    done
}

# Запуск главного меню
main_menu
