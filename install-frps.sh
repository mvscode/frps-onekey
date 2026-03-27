#!/bin/bash

# Set the PATH variable
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Initialize LATEST_RELEASE with a default value (can be overridden by user input)
LATEST_RELEASE=""
export FRPS_VER="$LATEST_RELEASE"
export FRPS_VER_32BIT="$LATEST_RELEASE"
export FRPS_INIT="https://raw.githubusercontent.com/mvscode/frps-onekey/master/frps.init"
export gitee_download_url="https://gitee.com/mvscode/frps-onekey/releases/download"
export github_download_url="https://github.com/fatedier/frp/releases/download"
export gitee_latest_version_api="https://gitee.com/api/v5/repos/mvscode/frps-onekey/releases/latest"
export github_latest_version_api="https://api.github.com/repos/fatedier/frp/releases/latest"

# Program information
program_name="frps"
version="1.0.7"
str_program_dir="/usr/local/${program_name}"
program_init="/etc/init.d/${program_name}"
program_config_file="frps.toml"
ver_file="/tmp/.frp_ver.sh"
str_install_shell="https://raw.githubusercontent.com/mvscode/frps-onekey/master/install-frps.sh"

# Ensure colors are set before use
fun_set_text_color() {
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELLOW='\E[1;33m'  # 修正拼写错误
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

fun_set_text_color

# Function to display frps banner
fun_frps() {
    local clear_flag=""
    clear_flag="$1"
    if [[ "${clear_flag}" == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+------------------------------------------------------------+"
    echo "|    frps for Linux Server, Author Clang, Mender MvsCode     |" 
    echo "|      A tool to auto-compile & install frps on Linux        |"
    echo "+------------------------------------------------------------+"
    echo ""
}

# Check if user is root
rootness() {
    if [[ $EUID -ne 0 ]]; then
        fun_frps
        echo -e "Error: This script must be run as root!" 1>&2
        exit 1
    fi
}

# Get a single character input
get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty "$SAVEDSTTY"
}

# Check Server OS
checkos() {
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Red Hat Enterprise Linux" /etc/issue || grep -Eq "Red Hat Enterprise Linux" /etc/*-release; then
        OS=RHEL
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        OS=Fedora
    elif grep -Eqi "Rocky" /etc/issue || grep -Eq "Rocky" /etc/*-release; then
        OS=Rocky
    elif grep -Eqi "AlmaLinux" /etc/issue || grep -Eq "AlmaLinux" /etc/*-release; then
        OS=AlmaLinux
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    else
        echo -e "Unsupported OS. Please use a supported Linux distribution and retry!" 1>&2
        exit 1
    fi
}

# Get version
getversion() {
    local version
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        version="$VERSION_ID"
    elif [[ -f /etc/redhat-release ]]; then
        version=$(grep -oE "[0-9.]+" /etc/redhat-release)
    else
        version=$(grep -oE "[0-9.]+" /etc/issue)
    fi

    if [[ -z "$version" ]]; then
        echo "Unable to determine version" >&2
        return 1
    else
        echo "$version"
    fi
}

# Check server OS version
check_os_version() {
    local required_version="$1"
    local current_version=$(getversion)
    
    if [[ "$(echo -e "$current_version\n$required_version" | sort -V | head -n1)" == "$required_version" ]]; then
        return 0  # Current version >= required version
    else
        return 1  # Current version < required version
    fi
}

# Check OS bit
check_os_bit() {
    local arch
    arch=$(uname -m)

    case $arch in
        x86_64)      Is_64bit='y'; ARCHS="amd64";;
        i386|i486|i586|i686) Is_64bit='n'; ARCHS="386"; FRPS_VER="$FRPS_VER_32BIT";;
        aarch64)     Is_64bit='y'; ARCHS="arm64";;
        arm*|armv*)  Is_64bit='n'; ARCHS="arm"; FRPS_VER="$FRPS_VER_32BIT";;
        mips)        Is_64bit='n'; ARCHS="mips"; FRPS_VER="$FRPS_VER_32BIT";;
        mips64)      Is_64bit='y'; ARCHS="mips64";;
        mips64el)    Is_64bit='y'; ARCHS="mips64le";;
        mipsel)      Is_64bit='n'; ARCHS="mipsle"; FRPS_VER="$FRPS_VER_32BIT";;
        riscv64)     Is_64bit='y'; ARCHS="riscv64";;
        *)           echo -e "Unknown architecture" >&2; exit 1;;
    esac
}

# Disable SELinux
disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0 2>/dev/null || true
    fi
}

# Install prerequisite packages
pre_install_packs() {
    local wget_flag=0
    local killall_flag=0
    local netstat_flag=0
    local curl_flag=0

    wget --version >/dev/null 2>&1 || wget_flag=$?
    killall -V >/dev/null 2>&1 || killall_flag=$?
    netstat --version >/dev/null 2>&1 || netstat_flag=$?
    curl --version >/dev/null 2>&1 || curl_flag=$?

    if [ $wget_flag -gt 0 ] || [ $killall_flag -gt 0 ] || [ $netstat_flag -gt 0 ] || [ $curl_flag -gt 0 ]; then
        echo -e "${COLOR_GREEN}Installing support packages...${COLOR_END}"
        if [ "$OS" == 'CentOS' ] || [ "$OS" == 'RHEL' ] || [ "$OS" == 'Rocky' ] || [ "$OS" == 'AlmaLinux' ]; then
            yum install -y wget psmisc net-tools curl || exit 1
        else
            apt-get -y update && apt-get -y install wget psmisc net-tools curl || exit 1
        fi
    fi
}

# Generate random string
fun_randstr() {
    local strNum="${1:-16}"
    tr -cd '[:alnum:]' < /dev/urandom | fold -w "$strNum" | head -n1
}

# Select download server
fun_getServer() {
    local def_server_url="github"
    echo ""
    echo -e "Please select ${COLOR_PINK}${program_name} download${COLOR_END} url:"
    echo -e "[1].gitee"
    echo -e "[2].github (default)"
    read -e -p "Enter your choice (1, 2 or exit. default [${def_server_url}]): " set_server_url
    [ -z "$set_server_url" ] && set_server_url="$def_server_url"
    case "$set_server_url" in
        1|[Gg][Ii][Tt][Ee][Ee])
            program_download_url="$gitee_download_url"
            choice=1
            ;;
        2|[Gg][Ii][Tt][Hh][Uu][Bb])
            program_download_url="$github_download_url"
            choice=2
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            program_download_url="$github_download_url"
            ;;
    esac
    echo "-----------------------------------"
    echo -e "       Your select: ${COLOR_YELLOW}${set_server_url}${COLOR_END}"
    echo "-----------------------------------"
}

# Get or set version (allow user input or fetch latest)
fun_getVer() {
    echo ""
    echo -e "Please select how to set ${program_name} version:"
    echo -e "[1]. Use latest version (default)"
    echo -e "[2]. Specify a custom version"
    read -e -p "Enter your choice (1, 2 or exit. default [1]): " version_choice
    [ -z "$version_choice" ] && version_choice="1"

    case "$version_choice" in
        1|[Ll][Aa][Tt][Ee][Ss][Tt])
            echo -e "Loading latest network version for ${program_name}, please wait..."
            case $choice in
                1)  LATEST_RELEASE=$(curl -s "$gitee_latest_version_api" | grep -oP '"tag_name":"\Kv[^"]+' | cut -c2-);;
                2)  LATEST_RELEASE=$(curl -s "$github_latest_version_api" | grep '"tag_name":' | cut -d '"' -f 4 | cut -c 2-);;
            esac
            if [[ -z "$LATEST_RELEASE" ]]; then
                echo -e "${COLOR_RED}Failed to retrieve the latest version.${COLOR_END}" >&2
                exit 1
            fi
            FRPS_VER="$LATEST_RELEASE"
            echo -e "${COLOR_GREEN}Latest version set to: ${FRPS_VER}${COLOR_END}"
            ;;
        2|[Cc][Uu][Ss][Tt][Oo][Mm])
            echo -n -e "Please input the custom ${program_name} version (e.g., 0.51.0): "
            read -e custom_version
            if [[ -z "$custom_version" ]]; then
                echo -e "${COLOR_RED}Version cannot be empty. Using latest version instead.${COLOR_END}"
                fun_getVer  # 递归调用以重新选择
                return
            fi
            # 验证版本号格式（简单检查，假设为 X.Y.Z 格式）
            if [[ "$custom_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                FRPS_VER="$custom_version"
                echo -e "${COLOR_GREEN}Custom version set to: ${FRPS_VER}${COLOR_END}"
            else
                echo -e "${COLOR_RED}Invalid version format. Please use X.Y.Z format (e.g., 0.51.0).${COLOR_END}"
                fun_getVer  # 递归调用以重新输入
                return
            fi
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            fun_getVer  # 默认使用最新版本，递归调用
            ;;
    esac

    program_latest_filename="frp_${FRPS_VER}_linux_${ARCHS}.tar.gz"
    program_latest_file_url="${program_download_url}/v${FRPS_VER}/${program_latest_filename}"
    if [ -z "$program_latest_filename" ]; then
        echo -e "${COLOR_RED}Failed to load version information!!!${COLOR_END}" >&2
        exit 1
    else
        echo -e "${program_name} Latest release file ${COLOR_GREEN}${program_latest_filename}${COLOR_END}"
    fi
}

# Download and extract frps
fun_download_file() {
    if [ ! -s "${str_program_dir}/${program_name}" ]; then
        rm -f "${program_latest_filename}" "frp_${FRPS_VER}_linux_${ARCHS}"
        echo -e "Downloading ${program_name}..."
        if ! curl -L --progress-bar "${program_latest_file_url}" -o "${program_latest_filename}"; then
            echo -e " ${COLOR_RED}Download failed${COLOR_END}"
            exit 1
        fi

        if [ ! -s "${program_latest_filename}" ]; then
            echo -e " ${COLOR_RED}Downloaded file is empty or not found${COLOR_END}"
            exit 1
        fi

        echo -e "Extracting ${program_name}..."
        tar xzf "${program_latest_filename}" || exit 1
        mv "frp_${FRPS_VER}_linux_${ARCHS}/frps" "${str_program_dir}/${program_name}" || exit 1
        rm -f "${program_latest_filename}" "frp_${FRPS_VER}_linux_${ARCHS}"
    fi

    chown root:root -R "${str_program_dir}"
    if [ -s "${str_program_dir}/${program_name}" ]; then
        [ ! -x "${str_program_dir}/${program_name}" ] && chmod 755 "${str_program_dir}/${program_name}"
    else
        echo -e " ${COLOR_RED}Extraction failed${COLOR_END}"
        exit 1
    fi
}

# Check port availability
fun_check_port() {
    local port_flag="$1"
    local strCheckPort="$2"
    if [[ "$strCheckPort" =~ ^[0-9]+$ ]] && [ "$strCheckPort" -ge 1 ] && [ "$strCheckPort" -le 65535 ]; then
        if netstat -ntulp | grep -q ":${strCheckPort}\b"; then
            echo -e "${COLOR_RED}Error:${COLOR_END} Port ${COLOR_GREEN}${strCheckPort}${COLOR_END} is ${COLOR_PINK}used${COLOR_END}:"
            netstat -ntulp | grep ":${strCheckPort}\b"
            return 1
        else
            input_port="$strCheckPort"
            return 0
        fi
    else
        echo "Input error! Please input a number between 1 and 65535."
        return 1
    fi
}

# Check number within range
fun_check_number() {
    local num_flag="$1"
    local strMaxNum="$2"
    local strCheckNum="$3"
    if [[ "$strCheckNum" =~ ^[0-9]+$ ]] && [ "$strCheckNum" -ge 1 ] && [ "$strCheckNum" -le "$strMaxNum" ]; then
        input_number="$strCheckNum"
    else
        echo "Input error! Please input a number between 1 and $strMaxNum."
        return 1
    fi
    return 0
}

# Input configuration data functions
fun_input_bind_port() {
    local def_server_port="5443"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default Server Port: ${def_server_port}): " serverport
    [ -z "$serverport" ] && serverport="$def_server_port"
    if ! fun_check_port "bind" "$serverport"; then
        fun_input_bind_port
    fi
    set_bind_port="$input_port"
}

fun_input_dashboard_port() {
    local def_dashboard_port="6443"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_dashboard_port}):" input_dashboard_port
    [ -z "$input_dashboard_port" ] && input_dashboard_port="$def_dashboard_port"
    if ! fun_check_port "dashboard" "$input_dashboard_port"; then
        fun_input_dashboard_port
    fi
    set_dashboard_port="$input_port"
}

fun_input_vhost_http_port() {
    local def_vhost_http_port="80"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_http_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhost_http_port}):" input_vhost_http_port
    [ -z "$input_vhost_http_port" ] && input_vhost_http_port="$def_vhost_http_port"
    if ! fun_check_port "vhost_http" "$input_vhost_http_port"; then
        fun_input_vhost_http_port
    fi
    set_vhost_http_port="$input_port"
}

fun_input_vhost_https_port() {
    local def_vhost_https_port="443"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_https_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhost_https_port}):" input_vhost_https_port
    [ -z "$input_vhost_https_port" ] && input_vhost_https_port="$def_vhost_https_port"
    if ! fun_check_port "vhost_https" "$input_vhost_https_port"; then
        fun_input_vhost_https_port
    fi
    set_vhost_https_port="$input_port"
}

fun_input_log_max_days() {
    local def_max_days="15"
    local def_log_max_days="3"
    echo -e "Please input ${program_name} ${COLOR_GREEN}log_max_days${COLOR_END} [1-${def_max_days}]"
    read -e -p "(Default : ${def_log_max_days} day):" input_log_max_days
    [ -z "$input_log_max_days" ] && input_log_max_days="$def_log_max_days"
    if ! fun_check_number "log_max_days" "$def_max_days" "$input_log_max_days"; then
        fun_input_log_max_days
    fi
    set_log_max_days="$input_number"
}

fun_input_max_pool_count() {
    local def_max_pool="50"
    local def_max_pool_count="5"
    echo -e "Please input ${program_name} ${COLOR_GREEN}max_pool_count${COLOR_END} [1-${def_max_pool}]"
    read -e -p "(Default : ${def_max_pool_count}):" input_max_pool_count
    [ -z "$input_max_pool_count" ] && input_max_pool_count="$def_max_pool_count"
    if ! fun_check_number "max_pool_count" "$def_max_pool" "$input_max_pool_count"; then
        fun_input_max_pool_count
    fi
    set_max_pool_count="$input_number"
}

fun_input_dashboard_user() {
    local def_dashboard_user="admin"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_user${COLOR_END}"
    read -e -p "(Default : ${def_dashboard_user}):" input_dashboard_user
    [ -z "$input_dashboard_user" ] && input_dashboard_user="$def_dashboard_user"
    set_dashboard_user="$input_dashboard_user"
}

fun_input_dashboard_pwd() {
    local def_dashboard_pwd=$(fun_randstr 8)
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_pwd${COLOR_END}"
    read -e -p "(Default : ${def_dashboard_pwd}):" input_dashboard_pwd
    [ -z "$input_dashboard_pwd" ] && input_dashboard_pwd="$def_dashboard_pwd"
    set_dashboard_pwd="$input_dashboard_pwd"
}

fun_input_token() {
    local def_token=$(fun_randstr 16)
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}token${COLOR_END}"
    read -e -p "(Default : ${def_token}):" input_token
    [ -z "$input_token" ] && input_token="$def_token"
    set_token="$input_token"
}

fun_input_subdomain_host() {
    local def_subdomain_host="$defIP"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}subdomain_host${COLOR_END}"
    read -e -p "(Default : ${def_subdomain_host}):" input_subdomain_host
    [ -z "$input_subdomain_host" ] && input_subdomain_host="$def_subdomain_host"
    set_subdomain_host="$input_subdomain_host"
}

fun_input_kcp_bind_port() {
    local def_kcp_bind_port="${set_bind_port:-5443}"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}kcp_bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default kcp bind port: ${def_kcp_bind_port}):" input_kcp_bind_port
    [ -z "$input_kcp_bind_port" ] && input_kcp_bind_port="$def_kcp_bind_port"
    if ! fun_check_port "kcp_bind" "$input_kcp_bind_port"; then
        fun_input_kcp_bind_port
    fi
    set_kcp_bind_port="$input_port"
}

fun_input_quic_bind_port() {
    local def_quic_bind_port="${set_vhost_https_port:-443}"
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}quic_bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default quic bind port: ${def_quic_bind_port}):" input_quic_bind_port
    [ -z "$input_quic_bind_port" ] && input_quic_bind_port="$def_quic_bind_port"
    if ! fun_check_port "quic_bind" "$input_quic_bind_port"; then
        fun_input_quic_bind_port
    fi
    set_quic_bind_port="$input_port"
}

# Pre-install frps checks and setup
pre_install_frps() {
    fun_frps
    echo -e "Check your server setting, please wait..."
    echo ""
    disable_selinux

    # Check if frps is already running
    if pgrep -x "${program_name}" >/dev/null; then
        echo -e "${COLOR_GREEN}${program_name} is already installed and running.${COLOR_END}"
        exit 0
    else
        echo -e "${COLOR_YELLOW}${program_name} is not running or not installed.${COLOR_END}"
        echo ""
        read -p "Do you want to install ${program_name}? (y/n) " choice
        echo ""
        case "$choice" in
            [yY])
                echo -e "${COLOR_GREEN}Installing ${program_name}...${COLOR_END}"
                ;;
            [nN])
                echo -e "${COLOR_YELLOW}Skipping installation.${COLOR_END}"
                exit 0
                ;;
            *)
                echo -e "${COLOR_YELLOW}Invalid choice. Skipping installation.${COLOR_END}"
                exit 0
                ;;
        esac
    fi

    clear
    fun_frps
    fun_getServer
    fun_getVer
    echo -e "Loading Your Server IP, please wait..."
    defIP=$(curl -s https://api.ipify.org) || defIP="Unknown"
    echo -e "Your Server IP: ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e ""
    echo -e "————————————————————————————————————————————"
    echo -e "     ${COLOR_RED}Please input your server settings:${COLOR_END}"
    echo -e "————————————————————————————————————————————"

    fun_input_bind_port
    echo -e "${program_name} bind_port: ${COLOR_YELLOW}${set_bind_port}${COLOR_END}"
    echo -e ""

    fun_input_vhost_http_port
    echo -e "${program_name} vhost_http_port: ${COLOR_YELLOW}${set_vhost_http_port}${COLOR_END}"
    echo -e ""

    fun_input_vhost_https_port
    echo -e "${program_name} vhost_https_port: ${COLOR_YELLOW}${set_vhost_https_port}${COLOR_END}"
    echo -e ""

    fun_input_dashboard_port
    echo -e "${program_name} dashboard_port: ${COLOR_YELLOW}${set_dashboard_port}${COLOR_END}"
    echo -e ""

    fun_input_dashboard_user
    echo -e "${program_name} dashboard_user: ${COLOR_YELLOW}${set_dashboard_user}${COLOR_END}"
    echo -e ""

    fun_input_dashboard_pwd
    echo -e "${program_name} dashboard_pwd: ${COLOR_YELLOW}${set_dashboard_pwd}${COLOR_END}"
    echo -e ""

    fun_input_token
    echo -e "${program_name} token: ${COLOR_YELLOW}${set_token}${COLOR_END}"
    echo -e ""

    fun_input_subdomain_host
    echo -e "${program_name} subdomain_host: ${COLOR_YELLOW}${set_subdomain_host}${COLOR_END}"
    echo -e ""

    fun_input_max_pool_count
    echo -e "${program_name} max_pool_count: ${COLOR_YELLOW}${set_max_pool_count}${COLOR_END}"
    echo -e ""

    echo -e "Please select ${COLOR_GREEN}log_level${COLOR_END}"
    echo "1: info (default)"
    echo "2: warn"
    echo "3: error"
    echo "4: debug"
    echo "5: trace"
    echo "-------------------------"
    read -e -p "Enter your choice (1, 2, 3, 4, 5 or exit. default [1]): " str_log_level
    case "${str_log_level}" in
        1|[Ii][Nn][Ff][Oo]) str_log_level="info";;
        2|[Ww][Aa][Rr][Nn]) str_log_level="warn";;
        3|[Ee][Rr][Rr][Oo][Rr]) str_log_level="error";;
        4|[Dd][Ee][Bb][Uu][Gg]) str_log_level="debug";;
        5|[Tt][Rr][Aa][Cc][Ee]) str_log_level="trace";;
        [eE][xX][iI][tT]) exit 1;;
        *) str_log_level="info";;
    esac
    echo -e "log_level: ${COLOR_YELLOW}${str_log_level}${COLOR_END}"
    echo -e ""

    fun_input_log_max_days
    echo -e "${program_name} log_max_days: ${COLOR_YELLOW}${set_log_max_days}${COLOR_END}"
    echo -e ""

    echo -e "Please select ${COLOR_GREEN}log_file${COLOR_END}"
    echo "1: enable (default)"
    echo "2: disable"
    echo "-------------------------"
    read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_log_file
    case "${str_log_file}" in
        1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
            str_log_file="./frps.log"
            str_log_file_flag="enable"
            ;;
        0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
            str_log_file="/dev/null"
            str_log_file_flag="disable"
            ;;
        [eE][xX][iI][tT]) exit 1;;
        *) str_log_file="./frps.log"; str_log_file_flag="enable";;
    esac
    echo -e "log_file: ${COLOR_YELLOW}${str_log_file_flag}${COLOR_END}"
    echo -e ""

    echo -e "Please select ${COLOR_GREEN}tcp_mux${COLOR_END}"
    echo "1: enable (default)"
    echo "2: disable"
    echo "-------------------------"
    read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_tcp_mux
    case "${str_tcp_mux}" in
        1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
            set_tcp_mux="true"
            ;;
        0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
            set_tcp_mux="false"
            ;;
        [eE][xX][iI][tT]) exit 1;;
        *) set_tcp_mux="true";;
    esac
    echo -e "tcp_mux: ${COLOR_YELLOW}${set_tcp_mux}${COLOR_END}"
    echo -e ""

    echo -e "Please select ${COLOR_GREEN}transport protocol support${COLOR_END}"
    echo "1: enable (default)"
    echo "2: disable"
    echo "-------------------------"
    read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_transport_protocol
    case "${str_transport_protocol}" in
        1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
            set_transport_protocol="enable"
            fun_input_kcp_bind_port
            fun_input_quic_bind_port
            ;;
        0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
            set_transport_protocol="disable"
            set_kcp_bind_port=0
            set_quic_bind_port=0
            ;;
        [eE][xX][iI][tT]) exit 1;;
        *) set_transport_protocol="enable"
           fun_input_kcp_bind_port
           fun_input_quic_bind_port
           ;;
    esac
    echo -e "transport protocol support: ${COLOR_YELLOW}${set_transport_protocol}${COLOR_END}"
    echo -e ""

    echo "============== Check your input =============="
    echo -e "Your Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "Bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
    echo -e "vhost HTTP port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
    echo -e "vhost HTTPS port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
    echo -e "Dashboard port     : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
    echo -e "Dashboard user     : ${COLOR_GREEN}${set_dashboard_user}${COLOR_END}"
    echo -e "Dashboard password : ${COLOR_GREEN}${set_dashboard_pwd}${COLOR_END}"
    echo -e "Token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
    echo -e "Subdomain host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}"
    echo -e "TCP mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}"
    echo -e "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
    echo -e "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
    echo -e "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
    echo -e "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
    echo -e "Transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
    echo -e "KCP bind port      : ${COLOR_GREEN}${set_kcp_bind_port}${COLOR_END}"
    echo -e "QUIC bind port     : ${COLOR_GREEN}${set_quic_bind_port}${COLOR_END}"
    echo "=============================================="
    echo ""
    echo "Press any key to start... or Press Ctrl+C to cancel"
    char=$(get_char)
    install_program_server_frps
}

# Install frps server
install_program_server_frps() {
    [ ! -d "$str_program_dir" ] && mkdir -p "$str_program_dir"
    cd "$str_program_dir" || exit 1
    echo "${program_name} install path: $PWD"

    echo -n "Configuring ${program_name}..."
    cat << EOF > "${str_program_dir}/${program_config_file}"
bindAddr = "0.0.0.0"
bindPort = ${set_bind_port}

# UDP port used for KCP protocol, can be same as 'bindPort'.
# If not set, KCP is disabled in frps.
kcpBindPort = ${set_kcp_bind_port}

# UDP port used for QUIC protocol.
# If not set, QUIC is disabled in frps.
quicBindPort = ${set_quic_bind_port}

# Heartbeat configure, not recommended to modify the default value
transport.heartbeatTimeout = 90

# Pool count in each proxy will keep no more than maxPoolCount.
transport.maxPoolCount = ${set_max_pool_count}

# If TCP stream multiplexing is used, default is true
transport.tcpMux = ${set_tcp_mux}

# If you want to support virtual host, you must set the HTTP/HTTPS ports (optional)
vhostHTTPPort = ${set_vhost_http_port}
vhostHTTPSPort = ${set_vhost_https_port}

# Configure the web server to enable the dashboard for frps.
webServer.addr = "0.0.0.0"
webServer.port = ${set_dashboard_port}
webServer.user = "${set_dashboard_user}"
webServer.password = "${set_dashboard_pwd}"

# Console or real log file path
log.to = "${str_log_file_flag}"
# Log level: trace, debug, info, warn, error
log.level = "${str_log_level}"
log.maxDays = ${set_log_max_days}

# Authentication method
auth.method = "token"
auth.token = "${set_token}"

# Subdomain host for HTTP/HTTPS proxies
subDomainHost = "${set_subdomain_host}"
EOF
    echo " done"

    echo -n "Downloading ${program_name}..."
    rm -f "${str_program_dir}/${program_name}" "$program_init"
    fun_download_file
    echo " done"

    echo -n "Downloading ${program_init}..."
    if [ ! -s "$program_init" ]; then
        if ! wget -q "$FRPS_INIT" -O "$program_init"; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
    fi
    [ ! -x "$program_init" ] && chmod +x "$program_init"
    echo " done"

    echo -n "Setting ${program_name} to start on boot..."
    if [ -d /etc/systemd/system ]; then
        # systemd 支持
        cat << EOF > /etc/systemd/system/${program_name}.service
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
ExecStart=${str_program_dir}/${program_name} -c ${str_program_dir}/${program_config_file}
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "$program_name"
        systemctl start "$program_name"
    elif [ "$OS" == 'CentOS' ] || [ "$OS" == 'RHEL' ] || [ "$OS" == 'Rocky' ] || [ "$OS" == 'AlmaLinux' ]; then
        chmod +x "$program_init"
        chkconfig --add "$program_name"
        "$program_init" start
    else
        chmod +x "$program_init"
        update-rc.d -f "$program_name" defaults
        "$program_init" start
    fi
    echo " done"

    # Verify service is running
    if [ -d /etc/systemd/system ]; then
        if systemctl is-active --quiet "$program_name"; then
            echo -e "${COLOR_GREEN}
┌─────────────────────────────────────────┐
│   ${program_name} service started successfully.     │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│  Installation completed successfully.   │
└─────────────────────────────────────────┘${COLOR_END}"
        else
            echo -e "${COLOR_RED}
┌─────────────────────────────────────────┐
│   ${program_name} service failed to start.          │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Installation failed, please re-install. │
└─────────────────────────────────────────┘${COLOR_END}"
            exit 1
        fi
    elif pgrep -x "$program_name" >/dev/null; then
        echo -e "${COLOR_GREEN}
┌─────────────────────────────────────────┐
│   ${program_name} service started successfully.     │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│  Installation completed successfully.   │
└─────────────────────────────────────────┘${COLOR_END}"
    else
        echo -e "${COLOR_RED}
┌─────────────────────────────────────────┐
│   ${program_name} service failed to start.          │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Installation failed, please re-install. │
└─────────────────────────────────────────┘${COLOR_END}"
        exit 1
    fi

    echo ""
    echo "Congratulations, ${program_name} install completed!"
    echo "================================================"
    echo -e "Your Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "Bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
    echo -e "vhost HTTP port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
    echo -e "vhost HTTPS port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
    echo -e "Token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
    echo -e "Subdomain host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}"
    echo -e "TCP mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}"
    echo -e "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
    echo -e "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
    echo -e "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
    echo -e "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
    echo -e "Transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
    echo -e "KCP bind port      : ${COLOR_GREEN}${set_kcp_bind_port}${COLOR_END}"
    echo -e "QUIC bind port     : ${COLOR_GREEN}${set_quic_bind_port}${COLOR_END}"
    echo "================================================"
    echo -e "${program_name} Dashboard     : ${COLOR_GREEN}http://${set_subdomain_host}:${set_dashboard_port}/${COLOR_END}"
    echo -e "Dashboard port     : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
    echo -e "Dashboard user     : ${COLOR_GREEN}${set_dashboard_user}${COLOR_END}"
    echo -e "Dashboard password : ${COLOR_GREEN}${set_dashboard_pwd}${COLOR_END}"
    echo "================================================"
    echo ""
    echo -e "${program_name} status manage : ${COLOR_PINKBACK_WHITEFONT}${program_name}${COLOR_END} {${COLOR_GREEN}start|stop|restart|status|config|version${COLOR_END}}"
    echo -e "Example:"
    echo -e "  start: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}start${COLOR_END}"
    echo -e "   stop: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}stop${COLOR_END}"
    echo -e "restart: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}restart${COLOR_END}"
    exit 0
}

# Configure frps
configure_program_server_frps() {
    if [ -s "${str_program_dir}/${program_config_file}" ]; then
        vi "${str_program_dir}/${program_config_file}"
    else
        echo -e "${COLOR_RED}${program_name} configuration file not found!${COLOR_END}" >&2
        exit 1
    fi
}

# Uninstall frps
uninstall_program_server_frps() {
    fun_frps
    if [ -s "$program_init" ] || [ -s "${str_program_dir}/${program_name}" ]; then
        echo "============== Uninstall ${program_name} =============="
        read -e -p "${COLOR_YELLOW}Do you want to uninstall? [Y/N]:${COLOR_END} " str_uninstall
        case "${str_uninstall}" in
            [yY]|[yY][eE][sS])
                echo ""
                echo "You selected [Yes], press any key to continue."
                char=$(get_char)

                # Stop frps server
                if [ -d /etc/systemd/system ]; then
                    systemctl stop "$program_name" 2>/dev/null || true
                    systemctl disable "$program_name" 2>/dev/null || true
                    rm -f "/etc/systemd/system/${program_name}.service"
                    systemctl daemon-reload
                else
                    "$program_init" stop 2>/dev/null || true
                fi

                rm -f "$program_init" "/var/run/${program_name}.pid" "/usr/bin/${program_name}"
                rm -fr "$str_program_dir"
                echo -e "${COLOR_GREEN}${program_name} uninstall successful!${COLOR_END}"
                ;;
            *)
                echo ""
                echo -e "${COLOR_YELLOW}You selected [No], shell exiting!${COLOR_END}"
                ;;
        esac
    else
        echo -e "${COLOR_YELLOW}${program_name} is not installed!${COLOR_END}"
    fi
    exit 0
}

# Update frps configuration
update_config_frps() {
    if [ ! -r "${str_program_dir}/${program_config_file}" ]; then
        echo -e "${COLOR_RED}Config file ${str_program_dir}/${program_config_file} not found.${COLOR_END}" >&2
        exit 1
    fi

    local search_dashboard_user=$(grep "^dashboard_user" "${str_program_dir}/${program_config_file}")
    local search_dashboard_pwd=$(grep "^dashboard_pwd" "${str_program_dir}/${program_config_file}")
    local search_kcp_bind_port=$(grep "^kcp_bind_port" "${str_program_dir}/${program_config_file}")
    local search_quic_bind_port=$(grep "^quic_bind_port" "${str_program_dir}/${program_config_file}")
    local search_tcp_mux=$(grep "^tcp_mux" "${str_program_dir}/${program_config_file}")
    local search_token=$(grep "privilege_token" "${str_program_dir}/${program_config_file}")
    local search_allow_ports=$(grep "privilege_allow_ports" "${str_program_dir}/${program_config_file}")

    if [ -z "$search_dashboard_user" ] || [ -z "$search_dashboard_pwd" ] || [ -z "$search_kcp_bind_port" ] || [ -z "$search_quic_bind_port" ] || [ -z "$search_tcp_mux" ] || [ ! -z "$search_token" ] || [ ! -z "$search_allow_ports" ]; then
        echo -e "${COLOR_GREEN}Configuration files need to be updated, now setting:${COLOR_END}"
        echo ""

        if [ ! -z "$search_token" ]; then
            sed -i "s/privilege_token/token/" "${str_program_dir}/${program_config_file}"
        fi

        if [ -z "$search_dashboard_user" ] && [ -z "$search_dashboard_pwd" ]; then
            local def_dashboard_user_update="admin"
            read -e -p "Please input dashboard_user (Default: ${def_dashboard_user_update}):" set_dashboard_user_update
            [ -z "$set_dashboard_user_update" ] && set_dashboard_user_update="$def_dashboard_user_update"
            echo "${program_name} dashboard_user: ${set_dashboard_user_update}"
            echo ""

            local def_dashboard_pwd_update=$(fun_randstr 8)
            read -e -p "Please input dashboard_pwd (Default: ${def_dashboard_pwd_update}):" set_dashboard_pwd_update
            [ -z "$set_dashboard_pwd_update" ] && set_dashboard_pwd_update="$def_dashboard_pwd_update"
            echo "${program_name} dashboard_pwd: ${set_dashboard_pwd_update}"
            echo ""

            sed -i "/dashboard_port =.*/a\dashboard_user = ${set_dashboard_user_update}\ndashboard_pwd = ${set_dashboard_pwd_update}\n" "${str_program_dir}/${program_config_file}"
        fi

        if [ -z "$search_kcp_bind_port" ]; then
            echo -e "${COLOR_GREEN}Please select transport protocol support${COLOR_END}"
            echo "1: enable (default)"
            echo "2: disable"
            echo "-------------------------"
            read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_transport_protocol
            case "${str_transport_protocol}" in
                1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                    set_transport_protocol="enable"
                    ;;
                0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                    set_transport_protocol="disable"
                    ;;
                [eE][xX][iI][tT]) exit 1;;
                *) set_transport_protocol="enable";;
            esac
            local def_kcp_bind_port=$(grep "^bind_port" "${str_program_dir}/${program_config_file}" | cut -d'=' -f2 | tr -d '[:space:]')
            if [[ "$set_transport_protocol" == "disable" ]]; then
                sed -i "/^bind_port =.*/a\# UDP port used for transport protocol, can be same with 'bind_port'\n# If not set, transport protocol is disabled in frps\n#kcp_bind_port = ${def_kcp_bind_port}\n" "${str_program_dir}/${program_config_file}"
            else
                sed -i "/^bind_port =.*/a\# UDP port used for transport protocol, can be same with 'bind_port'\n# If not set, KCP is disabled in frps\nkcp_bind_port = ${def_kcp_bind_port}\n" "${str_program_dir}/${program_config_file}"
            fi
        fi

        if [ -z "$search_tcp_mux" ]; then
            echo -e "${COLOR_GREEN}Please select tcp_mux${COLOR_END}"
            echo "1: enable (default)"
            echo "2: disable"
            echo "-------------------------"
            read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_tcp_mux
            case "${str_tcp_mux}" in
                1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                    set_tcp_mux="true"
                    ;;
                0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                    set_tcp_mux="false"
                    ;;
                [eE][xX][iI][tT]) exit 1;;
                *) set_tcp_mux="true";;
            esac
            sed -i "/^privilege_mode = true/d" "${str_program_dir}/${program_config_file}"
            sed -i "/^token =.*/a\# If TCP stream multiplexing is used, default is true\ntcp_mux = ${set_tcp_mux}\n" "${str_program_dir}/${program_config_file}"
        fi

        if [ ! -z "$search_allow_ports" ]; then
            sed -i "s/privilege_allow_ports/allow_ports/" "${str_program_dir}/${program_config_file}"
        fi

        local verify_dashboard_user=$(grep "^dashboard_user" "${str_program_dir}/${program_config_file}")
        local verify_dashboard_pwd=$(grep "^dashboard_pwd" "${str_program_dir}/${program_config_file}")
        local verify_kcp_bind_port=$(grep "^kcp_bind_port" "${str_program_dir}/${program_config_file}")
        local verify_quic_bind_port=$(grep "^quic_bind_port" "${str_program_dir}/${program_config_file}")
        local verify_tcp_mux=$(grep "^tcp_mux" "${str_program_dir}/${program_config_file}")
        local verify_token=$(grep "privilege_token" "${str_program_dir}/${program_config_file}")
        local verify_allow_ports=$(grep "privilege_allow_ports" "${str_program_dir}/${program_config_file}")

        if [ ! -z "$verify_dashboard_user" ] && [ ! -z "$verify_dashboard_pwd" ] && [ ! -z "$verify_kcp_bind_port" ] && [ ! -z "$verify_quic_bind_port" ] && [ ! -z "$verify_tcp_mux" ] && [ -z "$verify_token" ] && [ -z "$verify_allow_ports" ]; then
            echo -e "${COLOR_GREEN}Update configuration file successfully!!!${COLOR_END}"
        else
            echo -e "${COLOR_RED}Update configuration file failed!!!${COLOR_END}"
            exit 1
        fi
    fi
}

# Update frps
update_program_server_frps() {
    fun_frps "clear"

    if [ -s "$program_init" ] || [ -s "${str_program_dir}/${program_name}" ]; then
        echo "============== Update ${program_name} =============="
        update_config_frps
        checkos
        check_os_version
        check_os_bit
        fun_getVer

        local remote_init_version=$(wget -qO- "$FRPS_INIT" | sed -n '/^version/p' | cut -d'"' -f2)
        local local_init_version=$(sed -n '/^version/p' "$program_init" | cut -d'"' -f2)
        local install_shell="$strPath"

        if [ -n "$remote_init_version" ] && [ "$local_init_version" != "$remote_init_version" ]; then
            echo "========== Update ${program_name} ${program_init} =========="
            if ! wget "$FRPS_INIT" -O "$program_init"; then
                echo -e "${COLOR_RED}Failed to download ${program_name}.init file!${COLOR_END}" >&2
                exit 1
            else
                echo -e "${COLOR_GREEN}${program_init} Update successfully !!!${COLOR_END}"
            fi
        fi

        [ ! -d "$str_program_dir" ] && mkdir -p "$str_program_dir"
        echo -e "Loading network version for ${program_name}, please wait..."
        fun_getServer
        fun_getVer >/dev/null 2>&1
        local local_program_version="$("${str_program_dir}/${program_name}" --version 2>/dev/null || echo "0.0.0")"
        echo -e "${COLOR_GREEN}${program_name} local version ${local_program_version}${COLOR_END}"
        echo -e "${COLOR_GREEN}${program_name} remote version ${FRPS_VER}${COLOR_END}"

        if [ "$local_program_version" != "$FRPS_VER" ]; then
            echo -e "${COLOR_GREEN}Found a new version, updating now!!!${COLOR_END}"
            if [ -d /etc/systemd/system ]; then
                systemctl stop "$program_name" 2>/dev/null || true
            else
                "$program_init" stop 2>/dev/null || true
            fi
            sleep 1
            rm -f "/usr/bin/${program_name}" "${str_program_dir}/${program_name}"
            fun_download_file

            if [ -d /etc/systemd/system ]; then
                systemctl daemon-reload
                systemctl enable "$program_name"
                systemctl start "$program_name"
            elif [ "$OS" == 'CentOS' ] || [ "$OS" == 'RHEL' ] || [ "$OS" == 'Rocky' ] || [ "$OS" == 'AlmaLinux' ]; then
                chmod +x "$program_init"
                chkconfig --add "$program_name"
                "$program_init" start
            else
                chmod +x "$program_init"
                update-rc.d -f "$program_name" defaults
                "$program_init" start
            fi

            [ -s "$program_init" ] && ln -sf "$program_init" "/usr/bin/${program_name}"
            [ ! -x "$program_init" ] && chmod 755 "$program_init"
            echo -e "${COLOR_GREEN}${program_name} version $("${str_program_dir}/${program_name}" --version)${COLOR_END}"
            echo -e "${COLOR_GREEN}${program_name} update successful!${COLOR_END}"
        else
            echo -e "${COLOR_YELLOW}No update needed, current version is up-to-date${COLOR_END}"
        fi
    else
        echo -e "${COLOR_YELLOW}${program_name} is not installed!${COLOR_END}"
    fi
    exit 0
}

# Main script execution
clear
strPath=$(pwd)
rootness
checkos
check_os_version "7"  # Example minimum version requirement for CentOS/RHEL
check_os_bit
pre_install_packs
shell_update

# Handle command-line arguments
action="$1"
if [ -z "$action" ]; then
    fun_frps
    echo -e "Arguments error! [$action]"
    echo "Usage: $(basename "$0") {install|uninstall|update|config}"
    exit 1
else
    case "$action" in
        install)
            pre_install_frps 2>&1 | tee "/root/${program_name}-install.log"
            ;;
        config)
            configure_program_server_frps
            ;;
        uninstall)
            uninstall_program_server_frps 2>&1 | tee "/root/${program_name}-uninstall.log"
            ;;
        update)
            update_program_server_frps 2>&1 | tee "/root/${program_name}-update.log"
            ;;
        *)
            fun_frps
            echo -e "Arguments error! [$action]"
            echo "Usage: $(basename "$0") {install|uninstall|update|config}"
            exit 1
            ;;
    esac
fi