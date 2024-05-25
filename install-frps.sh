#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
###export###
export PATH
export FRPS_VER="$LATEST_RELEASE"
export FRPS_VER_32BIT="$LATEST_RELEASE"
export FRPS_INIT="https://raw.githubusercontent.com/MvsCode/frps-onekey/master/frps.init"
export gitee_download_url="https://gitee.com/Mvscode/frps-onekey/releases/download"
export github_download_url="https://github.com/fatedier/frp/releases/download"
export gitee_latest_version_api="https://gitee.com/api/v5/repos/MvsCode/frps-onekey/releases/latest"
export github_latest_version_api="https://api.github.com/repos/fatedier/frp/releases/latest"
#======================================================================
#   System Required:  CentOS Debian Ubuntu or Fedora(32bit/64bit)
#   Description:  A tool to auto-compile & install frps on Linux
#   Author : Clang
#   Mender : MvsCode
#======================================================================
program_name="frps"
version="20231028"
str_program_dir="/usr/local/${program_name}"
program_init="/etc/init.d/${program_name}"
program_config_file="frps.ini"
ver_file="/tmp/.frp_ver.sh"
str_install_shell="https://raw.githubusercontent.com/Mvscode/frps-onekey/master/install-frps.sh"
shell_update(){
    fun_clangcn "clear"
    echo "Check updates for shell..."
    remote_shell_version=`wget --no-check-certificate -qO- ${str_install_shell} | sed -n '/'^version'/p' | cut -d\" -f2`
    if [ ! -z ${remote_shell_version} ]; then
        if [[ "${version}" != "${remote_shell_version}" ]];then
            echo -e "${COLOR_GREEN}Found a new version, update now!!!${COLOR_END}"
            echo
            echo -n "Update shell ..."
            if ! wget --no-check-certificate -qO $0 ${str_install_shell}; then
                echo -e " [${COLOR_RED}failed${COLOR_END}]"
                echo
                exit 1
            else
                echo -e " [${COLOR_GREEN}OK${COLOR_END}]"
                echo
                echo -e "${COLOR_GREEN}Please Re-run${COLOR_END} ${COLOR_PINK}$0 ${clang_action}${COLOR_END}"
                echo
                exit 1
            fi
            exit 1
        fi
    fi
}
fun_clangcn(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+------------------------------------------------------------+"
    echo "|   frps for Linux Server, Author Clang ，Mender MvsCode     |" 
    echo "|      A tool to auto-compile & install frps on Linux        |"
    echo "+------------------------------------------------------------+"
    echo ""
}

fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}

# Check if user is root
rootness(){
    if [[ $EUID -ne 0 ]]; then
        fun_clangcn
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
checkos() {
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS="CentOS"
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS="Debian"
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS="Ubuntu"
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        OS="Fedora"
    else
        echo "Not supported OS, please reinstall OS and retry!"
        exit 1
    fi
}

getversion() {
    if [ -s /etc/redhat-release ]; then
        echo "$(grep -oE '[0-9.]+' /etc/redhat-release)"
    else
        echo "$(grep -oE '[0-9.]+' /etc/issue)"
    fi
}

centosversion() {
    local main_ver="${1%%.*}"
    local version="$(getversion)"
    if [ "${version%%.*}" -eq "$main_ver" ]; then
        return 0
    else
        return 1
    fi
}

check_os_bit() {
    case "$(uname -m)" in
        x86_64)      Is_64bit='y'; ARCHS="amd64";;
        i?86)        Is_64bit='n'; ARCHS="386"; FRPS_VER="$FRPS_VER_32BIT";;
        aarch64)     Is_64bit='y'; ARCHS="arm64";;
        arm*)        Is_64bit='n'; ARCHS="arm"; FRPS_VER="$FRPS_VER_32BIT";;
        mips)        Is_64bit='n'; ARCHS="mips"; FRPS_VER="$FRPS_VER_32BIT";;
        mips64)      Is_64bit='y'; ARCHS="mips64";;
        mips64el)    Is_64bit='y'; ARCHS="mips64le";;
        mipsel)      Is_64bit='n'; ARCHS="mipsle"; FRPS_VER="$FRPS_VER_32BIT";;
        riscv64)     Is_64bit='y'; ARCHS="riscv64";;
        *)           echo "Unknown architecture"; exit 1;;
    esac
}

check_centosversion() {
    if centosversion 5; then
        echo "Not supported CentOS 5.x, please change to CentOS 6, 7 or Debian, Ubuntu, or Fedora and try again."
        exit 1
    fi
}
disable_selinux() {
    if [ -s /etc/selinux/config ] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

pre_install_packs() {
    local packages=()
    for command in wget killall netstat; do
        if ! command -v "$command" &>/dev/null; then
            packages+=("$command")
        fi
    done
    if [ "${#packages[@]}" -gt 0 ]; then
        echo -e "${COLOR_GREEN} Installing support packages: ${packages[*]}${COLOR_END}"
        if [ "${OS}" == 'CentOS' ]; then
            yum install -y "${packages[@]}"
        else
            apt-get -y update && apt-get -y install "${packages[@]}"
        fi
    fi
}

fun_randstr() {
    local length="${1:-16}"
    echo "$(tr -cd '[:alnum:]' < /dev/urandom | fold -w "$length" | head -n1)"
}
fun_getServer() {
    local def_server_url="github"
    local set_server_url

    echo -e "Please select ${program_name} download url:"
    echo -e "[1] gitee"
    echo -e "[2] github (default)"
    read -rp "Enter your choice (1, 2 or exit. default [${def_server_url}]): " set_server_url

    case "${set_server_url:-2}" in
        1|[Gg][Ii][Tt][Ee][Ee])
            program_download_url="${gitee_download_url}"
            choice=1
            ;;
        2|[Gg][Ii][Tt][Hh][Uu][Bb])
            program_download_url="${github_download_url}"
            choice=2
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            program_download_url="${github_download_url}"
            ;;
    esac

    echo -e "       Your select: ${COLOR_YELOW}${set_server_url:-$def_server_url}${COLOR_END}"
    echo "-----------------------------------"
}

fun_getVer() {
    echo -e "Loading network version for ${program_name}, please wait..."

    case "$choice" in
        1)  LATEST_RELEASE=$(curl -s "${gitee_latest_version_api}" | grep -oP '"tag_name":"\Kv[^"]+' | cut -c2-) ;;
        2)  LATEST_RELEASE=$(curl -s "${github_latest_version_api}" | grep '"tag_name":' | cut -d '"' -f 4 | cut -c 2-) ;;
    esac

    if [ -n "$LATEST_RELEASE" ]; then
        FRPS_VER="$LATEST_RELEASE"
        echo "FRPS_VER set to: $FRPS_VER"
    else
        echo "Failed to retrieve the latest version."
    fi

    program_latest_filename="frp_${FRPS_VER}_linux_${ARCHS}.tar.gz"
    program_latest_file_url="${program_download_url}/v${FRPS_VER}/${program_latest_filename}"

    echo -e "${program_name} Latest release file ${COLOR_GREEN}${program_latest_filename}${COLOR_END}"
}

fun_download_file() {
    local program_path="${str_program_dir}/${program_name}"

    if [ ! -s "$program_path" ]; then
        rm -rf "$program_latest_filename" "frp_${FRPS_VER}_linux_${ARCHS}"
        if ! wget -q "$program_latest_file_url" -O "$program_latest_filename"; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
        tar xzf "$program_latest_filename"
        mv "frp_${FRPS_VER}_linux_${ARCHS}/frps" "$program_path"
        rm -rf "$program_latest_filename" "frp_${FRPS_VER}_linux_${ARCHS}"
    fi

    chown root:root -R "${str_program_dir}"
    if [ -s "$program_path" ]; then
        [ ! -x "$program_path" ] && chmod 755 "$program_path"
    else
        echo -e " ${COLOR_RED}failed${COLOR_END}"
        exit 1
    fi
}
__readINI() {
    local INIFILE=$1 SECTION=$2 ITEM=$3 _readIni
    _readIni=$(awk -F '=' -v section="$SECTION" -v item="$ITEM" '
        /^\[/{
            curr_section = substr($0, 2, length($0) - 2)
        }
        curr_section == section && $1 == item {
            print $2
            exit
        }
    ' "$INIFILE")
    echo "$_readIni"
}
fun_check_port() {
    local port_flag=$1 strCheckPort=$2
    if [ "$strCheckPort" -ge 1 ] && [ "$strCheckPort" -le 65535 ]; then
        if netstat -ntulp | grep -q "\b:$strCheckPort\b"; then
            echo -e "${COLOR_RED}Error:${COLOR_END} Port ${COLOR_GREEN}$strCheckPort${COLOR_END} is ${COLOR_PINK}used${COLOR_END}, view relevant port:"
            netstat -ntulp | grep "\b:$strCheckPort\b"
            fun_input_"$port_flag"_port
        else
            input_port=$strCheckPort
        fi
    else
        echo "Input error! Please input correct numbers."
        fun_input_"$port_flag"_port
    fi
}

fun_check_number() {
    local num_flag=$1 strMaxNum=$2 strCheckNum=$3
    if [ "$strCheckNum" -ge 1 ] && [ "$strCheckNum" -le "$strMaxNum" ]; then
        input_number=$strCheckNum
    else
        echo "Input error! Please input correct numbers."
        fun_input_"$num_flag"
    fi
}
# input configuration data code

fun_input_bind_port() {
    def_server_port="5443"
    echo -n "Please input ${program_name} ${COLOR_GREEN}bind_port${COLOR_END} [1-65535] (Default Server Port: ${def_server_port}): "
    read -e serverport
    [ -z "${serverport}" ] && serverport="${def_server_port}"
    fun_check_port "bind" "${serverport}"
}

fun_input_dashboard_port() {
    def_dashboard_port="6443"
    echo -n "Please input ${program_name} ${COLOR_GREEN}dashboard_port${COLOR_END} [1-65535] (Default: ${def_dashboard_port}): "
    read -e input_dashboard_port
    [ -z "${input_dashboard_port}" ] && input_dashboard_port="${def_dashboard_port}"
    fun_check_port "dashboard" "${input_dashboard_port}"
}

fun_input_vhost_http_port() {
    def_vhost_http_port="80"
    echo -n "Please input ${program_name} ${COLOR_GREEN}vhost_http_port${COLOR_END} [1-65535] (Default: ${def_vhost_http_port}): "
    read -e input_vhost_http_port
    [ -z "${input_vhost_http_port}" ] && input_vhost_http_port="${def_vhost_http_port}"
    fun_check_port "vhost_http" "${input_vhost_http_port}"
}

fun_input_vhost_https_port() {
    def_vhost_https_port="443"
    echo -n "Please input ${program_name} ${COLOR_GREEN}vhost_https_port${COLOR_END} [1-65535] (Default: ${def_vhost_https_port}): "
    read -e input_vhost_https_port
    [ -z "${input_vhost_https_port}" ] && input_vhost_https_port="${def_vhost_https_port}"
    fun_check_port "vhost_https" "${input_vhost_https_port}"
}

fun_input_log_max_days() {
    def_max_days="30"
    def_log_max_days="3"
    echo "Please input ${program_name} ${COLOR_GREEN}log_max_days${COLOR_END} [1-${def_max_days}] (Default: ${def_log_max_days} day): "
    read -e input_log_max_days
    [ -z "${input_log_max_days}" ] && input_log_max_days="${def_log_max_days}"
    fun_check_number "log_max_days" "${def_max_days}" "${input_log_max_days}"
}

fun_input_max_pool_count() {
    def_max_pool="200"
    def_max_pool_count="50"
    echo "Please input ${program_name} ${COLOR_GREEN}max_pool_count${COLOR_END} [1-${def_max_pool}] (Default: ${def_max_pool_count}): "
    read -e input_max_pool_count
    [ -z "${input_max_pool_count}" ] && input_max_pool_count="${def_max_pool_count}"
    fun_check_number "max_pool_count" "${def_max_pool}" "${input_max_pool_count}"
}

fun_input_dashboard_user() {
    def_dashboard_user="admin"
    echo -n "Please input ${program_name} ${COLOR_GREEN}dashboard_user${COLOR_END} (Default: ${def_dashboard_user}): "
    read -e input_dashboard_user
    [ -z "${input_dashboard_user}" ] && input_dashboard_user="${def_dashboard_user}"
}

fun_input_dashboard_pwd() {
    def_dashboard_pwd=$(fun_randstr 8)
    echo -n "Please input ${program_name} ${COLOR_GREEN}dashboard_pwd${COLOR_END} (Default: ${def_dashboard_pwd}): "
    read -e input_dashboard_pwd
    [ -z "${input_dashboard_pwd}" ] && input_dashboard_pwd="${def_dashboard_pwd}"
}

fun_input_token() {
    def_token=$(fun_randstr 16)
    echo -n "Please input ${program_name} ${COLOR_GREEN}token${COLOR_END} (Default: ${def_token}): "
    read -e input_token
    [ -z "${input_token}" ] && input_token="${def_token}"
}

fun_input_subdomain_host() {
    def_subdomain_host=${defIP}
    echo -n "Please input ${program_name} ${COLOR_GREEN}subdomain_host${COLOR_END} (Default: ${def_subdomain_host}): "
    read -e input_subdomain_host
    [ -z "${input_subdomain_host}" ] && input_subdomain_host="${def_subdomain_host}"
}
# Function to install Clang
install_clang() {
    # Install Clang
    echo "Installing Clang..."
}

# Function to disable SELinux
disable_selinux() {
    echo "Disabling SELinux..."
}

# Function to get server information
get_server_info() {
    echo "Retrieving server information..."
    defIP=$(wget -qO- http://ip.clang.cn | sed -r 's/\r//')
    echo "Your server IP: $defIP"
}

# Function to get user input
get_user_input() {
    echo "Please provide the following information:"

    read -p "Bind port: " bind_port
    read -p "Vhost HTTP port: " vhost_http_port
    read -p "Vhost HTTPS port: " vhost_https_port
    read -p "Dashboard port: " dashboard_port
    read -p "Dashboard user: " dashboard_user
    read -p "Dashboard password: " dashboard_pwd
    read -p "Token: " token
    read -p "Subdomain host: " subdomain_host
    read -p "Maximum pool count: " max_pool_count

    read -p "Log level (info, warn, error, debug): " log_level
}

# Main function
main() {
    install_clang
    disable_selinux
    get_server_info
    get_user_input

    echo "Program configuration:"
    echo "Bind port: $bind_port"
    echo "Vhost HTTP port: $vhost_http_port"
    echo "Vhost HTTPS port: $vhost_https_port"
    echo "Dashboard port: $dashboard_port"
    echo "Dashboard user: $dashboard_user"
    echo "Dashboard password: $dashboard_pwd"
    echo "Token: $token"
    echo "Subdomain host: $subdomain_host"
    echo "Maximum pool count: $max_pool_count"
    echo "Log level: $log_level"
}
main

# Colors
COLOR_YELLOW="\e[33m"
COLOR_GREEN="\e[32m"
COLOR_END="\e[0m"

# Functions
fun_input_log_max_days() {
    read -e -p "Enter log max days (default 7): " input_number
    [ -z "${input_number}" ] && input_number=7
}

# Log level
echo -e "log_level: ${COLOR_YELLOW}${str_log_level}${COLOR_END}"
echo

# Log max days
fun_input_log_max_days
[ -n "${input_number}" ] && set_log_max_days="${input_number}"
echo -e "${program_name} log_max_days: ${COLOR_YELLOW}${set_log_max_days}${COLOR_END}"
echo

# Log file
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
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        str_log_file="./frps.log"
        str_log_file_flag="enable"
        ;;
esac
echo -e "log_file: ${COLOR_YELLOW}${str_log_file_flag}${COLOR_END}"
echo

# TCP mux
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
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        set_tcp_mux="true"
        ;;
esac
echo -e "tcp_mux: ${COLOR_YELLOW}${set_tcp_mux}${COLOR_END}"
echo

# KCP support
echo -e "Please select ${COLOR_GREEN}kcp support${COLOR_END}"
echo "1: enable (default)"
echo "2: disable"
echo "-------------------------"
read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_kcp
case "${str_kcp}" in
    1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
        set_kcp="true"
        ;;
    0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
        set_kcp="false"
        ;;
    [eE][xX][iI][tT])
        exit 1
        ;;
    *)
        set_kcp="true"
        ;;
esac
echo -e "kcp support: ${COLOR_YELLOW}${set_kcp}${COLOR_END}"
echo
        echo "============== Check your input ==============" \
     "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}" \
     "Bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}" \
     "kcp support        : ${COLOR_GREEN}${set_kcp}${COLOR_END}" \
     "vhost http port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}" \
     "vhost https port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}" \
     "Dashboard port     : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}" \
     "Dashboard user     : ${COLOR_GREEN}${set_dashboard_user}${COLOR_END}" \
     "Dashboard password : ${COLOR_GREEN}${set_dashboard_pwd}${COLOR_END}" \
     "token              : ${COLOR_GREEN}${set_token}${COLOR_END}" \
     "subdomain_host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}" \
     "tcp_mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}" \
     "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}" \
     "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}" \
     "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}" \
     "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}" \
     "=============================================="

echo ""
echo "Press any key to start...or Press Ctrl+c to cancel"

char=`get_char`
install_program_server_clang() {
    # Create the program directory if it doesn't exist
    [[ ! -d "${str_program_dir}" ]] && mkdir -p "${str_program_dir}"
    cd "${str_program_dir}"
    echo "${program_name} install path: $PWD"

    echo -n "Generating config file for ${program_name} ..."

    # Generate the config file based on the set_kcp value
    if [[ "${set_kcp}" == "false" ]]; then
        cat > "${str_program_dir}/${program_config_file}" <<-EOF
        [common]
        bind_addr = 0.0.0.0
        bind_port = ${set_bind_port}
        dashboard_port = ${set_dashboard_port}
        dashboard_user = ${set_dashboard_user}
        dashboard_pwd = ${set_dashboard_pwd}
        vhost_http_port = ${set_vhost_http_port}
        vhost_https_port = ${set_vhost_https_port}
        log_file = ${str_log_file}
        log_level = ${str_log_level}
        log_max_days = ${set_log_max_days}
        token = ${set_token}
        subdomain_host = ${set_subdomain_host}
        max_pool_count = ${set_max_pool_count}
        tcp_mux = ${set_tcp_mux}
        EOF
    else
        cat > "${str_program_dir}/${program_config_file}" <<-EOF

        EOF
    fi
    echo "done."
}
# [common] is integral section
[common]
bind_addr = 0.0.0.0
bind_port = ${set_bind_port}
kcp_bind_port = ${set_bind_port}
dashboard_port = ${set_dashboard_port}
dashboard_user = ${set_dashboard_user}
dashboard_pwd = ${set_dashboard_pwd}
vhost_http_port = ${set_vhost_http_port}
vhost_https_port = ${set_vhost_https_port}
log_file = ${str_log_file}
log_level = ${str_log_level}
log_max_days = ${set_log_max_days}
token = ${set_token}
subdomain_host = ${set_subdomain_host}
max_pool_count = ${set_max_pool_count}
tcp_mux = ${set_tcp_mux}
EOF
fi

echo " done"

echo -n "downloading ${program_name} ..."
rm -f "${str_program_dir}/${program_name}" "${program_init}"
fun_download_file
echo " done"

echo -n "downloading ${program_init} ..."
if [ ! -s "${program_init}" ]; then
    if ! wget -q "${FRPS_INIT}" -O "${program_init}"; then
        echo -e " ${COLOR_RED}failed${COLOR_END}"
        exit 1
    fi
fi
chmod +x "${program_init}"
echo " done"

echo -n "setting ${program_name} boot ..."
chmod +x "${program_init}"
if [ "${OS}" == 'CentOS' ]; then
    chkconfig --add "${program_name}"
else
    update-rc.d -f "${program_name}" defaults
fi
echo " done"

[ -s "${program_init}" ] && ln -s "${program_init}" "/usr/bin/${program_name}"
"${program_init}" start
fun_clangcn
print_install_success() {
    echo ""
    echo "Congratulations, ${program_name} install completed!"
    echo "================================================"
}

print_server_info() {
    echo -e "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "Bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
    echo -e "KCP support        : ${COLOR_GREEN}${set_kcp}${COLOR_END}"
    echo -e "vhost http port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
    echo -e "vhost https port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
    echo -e "Dashboard port     : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
    echo -e "token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
    echo -e "subdomain_host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}"
    echo -e "tcp_mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}"
    echo -e "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
    echo -e "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
    echo -e "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
    echo -e "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
}

print_dashboard_info() {
    echo -e "${program_name} Dashboard     : ${COLOR_GREEN}http://${set_subdomain_host}:${set_dashboard_port}/${COLOR_END}"
    echo -e "Dashboard user     : ${COLOR_GREEN}${set_dashboard_user}${COLOR_END}"
    echo -e "Dashboard password : ${COLOR_GREEN}${set_dashboard_pwd}${COLOR_END}"
}

print_management_instructions() {
    echo "================================================"
    echo -e "${program_name} status manage : ${COLOR_PINKBACK_WHITEFONT}${program_name}${COLOR_END} {${COLOR_GREEN}start|stop|restart|status|config|version${COLOR_END}}"
    echo -e "Example:"
    echo -e "  start: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}start${COLOR_END}"
    echo -e "   stop: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}stop${COLOR_END}"
    echo -e "restart: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}restart${COLOR_END}"
}

# Call the functions in the main block
print_install_success
print_server_info
print_dashboard_info
print_management_instructions
exit 0
configure_program_server_clang() {
    local config_file="${str_program_dir}/${program_config_file}"

    if [ -s "$config_file" ]; then
        vi "$config_file"
    else
        echo "${program_name} configuration file not found: $config_file"
        return 1
    fi
}
uninstall_program_server_clang() {
    local program_init="${program_init}"
    local program_dir="${str_program_dir}"
    local program_name="${program_name}"

    fun_clangcn

    if [ -s "$program_init" ] || [ -s "$program_dir/$program_name" ]; then
        echo "============== Uninstall $program_name =============="
        read -rp "${COLOR_YELLOW}You want to uninstall? [Y/N]: ${COLOR_END}" str_uninstall

        case "${str_uninstall,,}" in
            [yY]*)
                echo "You select [Yes], press any key to continue."
                read -rn1
                checkos

                "$program_init" stop

                if [ "$OS" == 'CentOS' ]; then
                    chkconfig --del "$program_name"
                else
                    update-rc.d -f "$program_name" remove
                fi

                rm -f "$program_init" "/var/run/$program_name.pid" "/usr/bin/$program_name"
                rm -rf "$program_dir"
                echo "$program_name uninstall success!"
            ;;
            *)
                echo "You select [No], exiting."
            ;;
        esac
    else
        echo "$program_name is not installed!"
    fi

    return 0
}
update_config_clang() {
    if [ ! -r "${str_program_dir}/${program_config_file}" ]; then
        echo "config file ${str_program_dir}/${program_config_file} not found."
        return 1
    fi

    # Search for configuration parameters
    search_dashboard_user=$(grep "dashboard_user" "${str_program_dir}/${program_config_file}")
    search_dashboard_pwd=$(grep "dashboard_pwd" "${str_program_dir}/${program_config_file}")
    search_kcp_bind_port=$(grep "kcp_bind_port" "${str_program_dir}/${program_config_file}")
    search_tcp_mux=$(grep "tcp_mux" "${str_program_dir}/${program_config_file}")
    search_token=$(grep "privilege_token" "${str_program_dir}/${program_config_file}")
    search_allow_ports=$(grep "privilege_allow_ports" "${str_program_dir}/${program_config_file}")

    # Check if configuration needs to be updated
    if [ -z "${search_dashboard_user}" ] || [ -z "${search_dashboard_pwd}" ] || [ -z "${search_kcp_bind_port}" ] || [ -z "${search_tcp_mux}" ] || [ -n "${search_token}" ] || [ -n "${search_allow_ports}" ]; then
        echo -e "${COLOR_GREEN}Configuration files need to be updated, now setting:${COLOR_END}"

        # Update 'privilege_token' to 'token'
        if [ -n "${search_token}" ]; then
            sed -i "s/privilege_token/token/" "${str_program_dir}/${program_config_file}"
        fi

        # Update 'dashboard_user' and 'dashboard_pwd'
        if [ -z "${search_dashboard_user}" ] && [ -z "${search_dashboard_pwd}" ]; then
            def_dashboard_user_update="admin"
            read -e -p "Please input dashboard_user (Default: ${def_dashboard_user_update}):" set_dashboard_user_update
            [ -z "${set_dashboard_user_update}" ] && set_dashboard_user_update="${def_dashboard_user_update}"
            echo "${program_name} dashboard_user: ${set_dashboard_user_update}"

            def_dashboard_pwd_update=$(fun_randstr 8)
            read -e -p "Please input dashboard_pwd (Default: ${def_dashboard_pwd_update}):" set_dashboard_pwd_update
            [ -z "${set_dashboard_pwd_update}" ] && set_dashboard_pwd_update="${def_dashboard_pwd_update}"
            echo "${program_name} dashboard_pwd: ${set_dashboard_pwd_update}"

            sed -i "/dashboard_port =.*/a\dashboard_user = ${set_dashboard_user_update}\ndashboard_pwd = ${set_dashboard_pwd_update}\n" "${str_program_dir}/${program_config_file}"
        fi

        # Update 'kcp_bind_port'
        if [ -z "${search_kcp_bind_port}" ]; then
            set_kcp=$(ask_user_input "Please select kcp support" "1: enable (default)" "2: disable" "1")
            def_kcp_bind_port=$(__readINI "${str_program_dir}/${program_config_file}" common bind_port)
            if [ "$set_kcp" == "false" ]; then
                sed -i "/^bind_port =.*/a\# udp port used for kcp protocol, it can be same with 'bind_port'\n# if not set, kcp is disabled in frps\n#kcp_bind_port = ${def_kcp_bind_port}\n" "${str_program_dir}/${program_config_file}"
            else
                sed -i "/^bind_port =.*/a\# udp port used for kcp protocol, it can be same with 'bind_port'\n# if not set, kcp is disabled in frps\nkcp_bind_port = ${def_kcp_bind_port}\n" "${str_program_dir}/${program_config_file}"
            fi
        fi

        # Update 'tcp_mux'
        if [ -z "${search_tcp_mux}" ]; then
            set_tcp_mux=$(ask_user_input "Please select tcp_mux" "1: enable (default)" "2: disable" "1")
            sed -i "/^privilege_mode = true/d" "${str_program_dir}/${program_config_file}"
            sed -i "/^token =.*/a\# if tcp stream multiplexing is used, default is true\ntcp_mux = ${set_tcp_mux}\n" "${str_program_dir}/${program_config_file}"
        fi

        # Update 'privilege_allow_ports' to 'allow_ports'
        if [ -n "${search_allow_ports}" ]; then
            sed -i "s/privilege_allow_ports/allow_ports/" "${str_program_dir}/${program_config_file}"
        fi
    fi

    # Verify the updated configuration
    verify_dashboard_user=$(grep "^dashboard_user" "${str_program_dir}/${program_config_file}")
    verify_dashboard_pwd=$(grep "^dashboard_pwd" "${str_program_dir}/${program_config_file}")
    verify_kcp_bind_port=$(grep "kcp_bind_port" "${str_program_dir}/${program_config_file}")
    verify_tcp_mux=$(grep "^tcp_mux" "${str_program_dir}/${program_config_file}")
    verify_token=$(grep "privilege_token" "${str_program_dir}/${program_config_file}")
    verify_allow_ports=$(grep "privilege_allow_ports" "${str_program_dir}/${program_config_file}")

    if [ -n "${verify_dashboard_user}" ] && [ -n "${verify_dashboard_pwd}" ] && [ -n "${verify_kcp_bind_port}" ] && [ -n "${verify_tcp_mux}" ] && [ -z "${verify_token}" ] && [ -z "${verify_allow_ports}" ]; then
        echo -e "${COLOR_GREEN}Update configuration file successfully!!!${COLOR_END}"
    else
        echo -e "${COLOR_RED}Update configuration file error!!!${COLOR_END}"
    fi
}

# Helper function to ask user for input with default value
ask_user_input() {
    local prompt="$1"
    local option1="$2"
    local option2="$3"
    local default="$4"

    echo "$prompt"
    echo "$option1"
    echo "$option2"
    echo "-------------------------"
    read -e -p "Enter your choice (1, 2 or exit. default [$default]): " user_input
    case "$user_input" in
        1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
            echo "$option1"
            echo "$option1" | sed 's/\([^(]*\) (.*/\1/'
            ;;
        0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
            echo "$option2"
            echo "$option2" | sed 's/\([^(]*\) (.*/\1/'
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            echo "$option1"
            echo "$option1" | sed 's/\([^(]*\) (.*/\1/'
            ;;
    esac
}
update_program_server_clang() {
    clear_screen
    if [ -s "${program_init}" ] || [ -s "${str_program_dir}/${program_name}" ]; then
        echo "============== Update ${program_name} =============="
        update_config_clang
        check_os
        check_centos_version
        check_os_bit
        get_version_info
        if [ -n "${remote_init_version}" ] && [ "${local_init_version}" != "${remote_init_version}" ]; then
            echo "========== Update ${program_name} ${program_init} =========="
            if ! download_file "${FRPS_INIT}" "${program_init}"; then
                echo "Failed to download ${program_name}.init file!" >&2
                return 1
            else
                echo -e "${COLOR_GREEN}${program_init} Update successfully !!!${COLOR_END}"
            fi
        fi
        create_program_directory
        echo -e "Loading network version for ${program_name}, please wait..."
        download_program
        get_version_info >/dev/null 2>&1
        echo -e "${COLOR_GREEN}${program_name} local version ${local_program_version}${COLOR_END}"
        echo -e "${COLOR_GREEN}${program_name} remote version ${FRPS_VER}${COLOR_END}"
        if [ "${local_program_version}" != "${FRPS_VER}" ]; then
            echo -e "${COLOR_GREEN}Found a new version, updating now!!!${COLOR_END}"
            stop_program
            remove_program_files
            install_program
            start_program
            echo "${program_name} version `${str_program_dir}/${program_name} --version`"
            echo "${program_name} update success!"
        else
            echo -e "no need to update !!!${COLOR_END}"
        fi
    else
        echo "${program_name} Not installed!"
    fi
    return 0
}
