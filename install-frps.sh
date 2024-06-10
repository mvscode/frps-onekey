#!/bin/bash

# Set the PATH variable
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Set environment variables
export FRPS_VER="$LATEST_RELEASE"
export FRPS_VER_32BIT="$LATEST_RELEASE"
export FRPS_INIT="https://raw.githubusercontent.com/MvsCode/frps-onekey/master/frps.init"
export gitee_download_url="https://gitee.com/Mvscode/frps-onekey/releases/download"
export github_download_url="https://github.com/fatedier/frp/releases/download"
export gitee_latest_version_api="https://gitee.com/api/v5/repos/MvsCode/frps-onekey/releases/latest"
export github_latest_version_api="https://api.github.com/repos/fatedier/frp/releases/latest"

# Program information
program_name="frps"
version="1.0.1"
str_program_dir="/usr/local/${program_name}"
program_init="/etc/init.d/${program_name}"
program_config_file="frps.toml"
ver_file="/tmp/.frp_ver.sh"
str_install_shell="https://raw.githubusercontent.com/Mvscode/frps-onekey/master/install-frps.sh"

# Function to check for shell updates
shell_update() {
    # Clear the terminal
    fun_frps "clear"

    # Echo a message to indicate that we're checking for shell updates
    echo "Checking for shell updates..."

    # Fetch the remote shell version from the specified URL
    remote_shell_version=$(wget --no-check-certificate -qO- "${str_install_shell}" | sed -n '/^version/p' | cut -d'"' -f2)

    # Check if the remote shell version is not empty
    if [ -n "${remote_shell_version}" ]; then
        # Check if the local version is different from the remote version
        if [[ "${version}" != "${remote_shell_version}" ]]; then
            # Echo a message to indicate that a new version has been found
            echo -e "${COLOR_GREEN}Found a new version: ${remote_shell_version}${COLOR_END}"
            echo -e "Do you want to update? (y/n, default: y): "
            read -e -p "" user_choice
            user_choice=${user_choice:-y}
            if [[ "${user_choice}" =~ ^[Yy]$ ]]; then
                # Echo a message to indicate that we're updating the shell
                echo -n "Updating shell..."
                # Attempt to download the new version and overwrite the current script
                if ! wget --no-check-certificate -qO "$0" "${str_install_shell}"; then
                    # Echo a message to indicate that the update failed
                    echo -e " [${COLOR_RED}failed${COLOR_END}]"
                    echo
                    exit 1
                else
                    # Echo a message to indicate that the update was successful
                    echo -e " [${COLOR_GREEN}OK${COLOR_END}]"
                    echo
                    # Echo a message to instruct the user to re-run the script
                    echo -e "${COLOR_GREEN}Please re-run${COLOR_END} ${COLOR_PINK}$0 ${clang_action}${COLOR_END}"
                    echo
                    exit 1
                fi
            else
                echo "Update canceled."
            fi
        fi
    fi
}
fun_frps(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+------------------------------------------------------------+"
    echo "|   frps for Linux Server, Author Clang, Mender MvsCode     |" 
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
        fun_frps
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
# Check OS
checkos(){
    if   grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        OS=Fedora
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}
# Get version
getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}
# CentOS version
centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
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
        *)           echo "Unknown architecture";;
    esac
}
check_centosversion(){
if centosversion 5; then
    echo "Not support CentOS 5.x, please change to CentOS 6,7 or Debian or Ubuntu or Fedora and try again."
    exit 1
fi
}
# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}
pre_install_packs(){
    local wget_flag=''
    local killall_flag=''
    local netstat_flag=''
    wget --version > /dev/null 2>&1
    wget_flag=$?
    killall -V >/dev/null 2>&1
    killall_flag=$?
    netstat --version >/dev/null 2>&1
    netstat_flag=$?
    if [[ ${wget_flag} -gt 1 ]] || [[ ${killall_flag} -gt 1 ]] || [[ ${netstat_flag} -gt 6 ]];then
        echo -e "${COLOR_GREEN} Install support packs...${COLOR_END}"
        if [ "${OS}" == 'CentOS' ]; then
            yum install -y wget psmisc net-tools
        else
            apt-get -y update && apt-get -y install wget psmisc net-tools
        fi
    fi
}
# Random password
fun_randstr(){
    strNum=$1
    [ -z "${strNum}" ] && strNum="16"
    strRandomPass=""
    strRandomPass=`tr -cd '[:alnum:]' < /dev/urandom | fold -w ${strNum} | head -n1`
    echo ${strRandomPass}
}
fun_getServer(){
    def_server_url="github"
    echo ""
    echo -e "Please select ${program_name} download url:"
    echo -e "[1].gitee"
    echo -e "[2].github (default)"
    read -e -p "Enter your choice (1, 2 or exit. default [${def_server_url}]): " set_server_url
    [ -z "${set_server_url}" ] && set_server_url="${def_server_url}"
    case "${set_server_url}" in
        1|[Ga][Ii][Tt][Ee][Ee])
            program_download_url=${gitee_download_url};
            choice=1
            ;;
        2|[Gg][Ii][Tt][Hh][Uu][Bb])
            program_download_url=${github_download_url};
            choice=2
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            program_download_url=${github_download_url}
            ;;
    esac
    echo    "-----------------------------------"
    echo -e "       Your select: ${COLOR_YELOW}${set_server_url}${COLOR_END}    "
    echo    "-----------------------------------"
}
fun_getVer(){
    echo -e "Loading network version for ${program_name}, please wait..."
    case $choice in
        1)  LATEST_RELEASE=$(curl -s ${gitee_latest_version_api} | grep -oP '"tag_name":"\Kv[^"]+' | cut -c2-);;
        2)  LATEST_RELEASE=$(curl -s ${github_latest_version_api} | grep '"tag_name":' | cut -d '"' -f 4 | cut -c 2-);;
    esac
    if [[ ! -z "$LATEST_RELEASE" ]]; then
        FRPS_VER="$LATEST_RELEASE"
        echo "FRPS_VER set to: $FRPS_VER"
    else
        echo "Failed to retrieve the latest version."
    fi
    program_latest_filename="frp_${FRPS_VER}_linux_${ARCHS}.tar.gz"
    program_latest_file_url="${program_download_url}/v${FRPS_VER}/${program_latest_filename}"
    if [ -z "${program_latest_filename}" ]; then
        echo -e "${COLOR_RED}Load network version failed!!!${COLOR_END}"
    else
        echo -e "${program_name} Latest release file ${COLOR_GREEN}${program_latest_filename}${COLOR_END}"
    fi
}
fun_download_file(){
    # download
    if [ ! -s ${str_program_dir}/${program_name} ]; then
        rm -fr ${program_latest_filename} frp_${FRPS_VER}_linux_${ARCHS}
        if ! wget  -q ${program_latest_file_url} -O ${program_latest_filename}; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
        tar xzf ${program_latest_filename}
        mv frp_${FRPS_VER}_linux_${ARCHS}/frps ${str_program_dir}/${program_name}
        rm -fr ${program_latest_filename} frp_${FRPS_VER}_linux_${ARCHS}
    fi
    chown root:root -R ${str_program_dir}
    if [ -s ${str_program_dir}/${program_name} ]; then
        [ ! -x ${str_program_dir}/${program_name} ] && chmod 755 ${str_program_dir}/${program_name}
    else
        echo -e " ${COLOR_RED}failed${COLOR_END}"
        exit 1
    fi
}
function __readINI() {
 INIFILE=$1; SECTION=$2; ITEM=$3
 _readIni=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$ITEM'/{print $2;exit}' $INIFILE`
echo ${_readIni}
}
# Check port
fun_check_port(){
    port_flag=""
    strCheckPort=""
    input_port=""
    port_flag="$1"
    strCheckPort="$2"
    if [ ${strCheckPort} -ge 1 ] && [ ${strCheckPort} -le 65535 ]; then
        checkbindPort=`netstat -ntulp | grep "\b:${strCheckPort}\b"`
        if [ -n "${checkbindPort}" ]; then
            echo ""
            echo -e "${COLOR_RED}Error:${COLOR_END} Port ${COLOR_GREEN}${strCheckPort}${COLOR_END} is ${COLOR_PINK}used${COLOR_END},view relevant port:"
            netstat -ntulp | grep "\b:${strCheckPort}\b"
            fun_input_${port_flag}_port
        else
            input_port="${strCheckPort}"
        fi
    else
        echo "Input error! Please input correct numbers."
        fun_input_${port_flag}_port
    fi
}
fun_check_number(){
    num_flag="" 
    strMaxNum="" 
    strCheckNum="" 
    input_number=""
    num_flag="$1"
    strMaxNum="$2"
    strCheckNum="$3"
    if [ ${strCheckNum} -ge 1 ] && [ ${strCheckNum} -le ${strMaxNum} ]; then
        input_number="${strCheckNum}"
    else
        echo "Input error! Please input correct numbers."
        fun_input_${num_flag}
    fi
}
# input configuration data
fun_input_bindPort(){
    def_bindPort="7000"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}bindPort${COLOR_END} [1-65535]"
    read -e -p "(Default Server Port: ${def_bindPort}):" bindPort
    [ -z "${bindPort}" ] && bindPort="${def_bindPort}"
    fun_check_port "bind" "${bindPort}"
}
fun_input_vhostHTTPPort(){
    def_vhostHTTPPort="80"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhostHTTPPort${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhostHTTPPort}):" input_vhostHTTPPort
    [ -z "${input_vhostHTTPPort}" ] && input_vhostHTTPPort="${def_vhostHTTPPort}"
    fun_check_port "vhostHTTP" "${input_vhostHTTPPort}"
}
fun_input_vhostHTTPSPort(){
    def_vhostHTTPSPort="443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhostHTTPSPort${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhostHTTPSPort}):" input_vhostHTTPSPort
    [ -z "${input_vhostHTTPSPort}" ] && input_vhostHTTPSPort="${def_vhostHTTPSPort}"
    fun_check_port "vhostHTTPS" "${input_vhostHTTPSPort}"
}
fun_input_token(){
    def_token=`fun_randstr 16`
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}token${COLOR_END}"
    read -e -p "(Default : ${def_token}):" input_token
    [ -z "${input_token}" ] && input_token="${def_token}"
}	
fun_input_webServerport(){
    def_webServerport="7500"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}webServerport${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_webServerport}):" input_webServerport
    [ -z "${input_webServerport}" ] && input_webServerport="${def_webServerport}"
    fun_check_port "webServer" "${input_webServerport}"
}
fun_input_webServeruser(){
    def_webServeruser="admin"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}webServeruser${COLOR_END}"
    read -e -p "(Default : ${def_webServeruser}):" input_webServeruser
    [ -z "${input_webServeruser}" ] && input_webServeruser="${def_webServeruser}"
}
fun_input_webServerpassword(){
    def_webServerpassword=`fun_randstr 8`
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}webServerpassword${COLOR_END}"
    read -e -p "(Default : ${def_webServerpassword}):" input_webServerpassword
    [ -z "${input_webServerpassword}" ] && input_webServerpassword="${def_webServerpassword}"
}
fun_input_logmaxDays(){
    def_maxdays="30" 
    def_logmaxDays="3"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}logmaxDays${COLOR_END} [1-${def_maxdays}]"
    read -e -p "(Default : ${def_logmaxDays} day):" input_logmaxDays
    [ -z "${input_logmaxDays}" ] && input_logmaxDays="${def_logmaxDays}"
    fun_check_number "logmaxDays" "${def_maxdays}" "${input_logmaxDays}"
}
fun_input_transportmaxPoolCount(){
    def_maxPool="200"
    def_transportmaxPoolCount="50"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}transportmaxPoolCount${COLOR_END} [1-${def_maxPool}]"
    read -e -p "(Default : ${def_transportmaxPoolCount}):" input_transportmaxPoolCount
    [ -z "${input_transportmaxPoolCount}" ] && input_transportmaxPoolCount="${def_transportmaxPoolCount}"
    fun_check_number "transportmaxPoolCount" "${def_maxPool}" "${input_transportmaxPoolCount}"
}
fun_input_subDomainHost(){
    def_subDomainHost=${defIP}
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}subDomainHost${COLOR_END}"
    read -e -p "(Default : ${def_subDomainHost}):" input_subDomainHost
    [ -z "${input_subDomainHost}" ] && input_subDomainHost="${def_subDomainHost}"
}

pre_install_frps(){
    fun_frps
    echo -e "Check your server setting, please wait..."
    disable_selinux
    if [ -s ${str_program_dir}/${program_name} ] && [ -s ${program_init} ]; then
        echo "${program_name} is installed!"
    else
        clear
        fun_frps
        fun_getServer
        fun_getVer
        echo -e "Loading You Server IP, please wait..."
        defIP=$(wget -qO- ifconfig.co 2>/dev/null | sed -r 's/\r//')
        echo -e "You Server IP:${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e "ââââââââââââââââââââââââââââââââââââââââââââ"
        echo -e "     ${COLOR_RED}Please input your server setting:${COLOR_END}"
        echo -e "ââââââââââââââââââââââââââââââââââââââââââââ"
        fun_input_bindPort
        [ -n "${input_port}" ] && set_bindPort="${input_port}"
        echo -e "${program_name} bindPort: ${COLOR_YELOW}${set_bindPort}${COLOR_END}"
        echo -e ""
        fun_input_vhostHTTPPort
        [ -n "${input_port}" ] && set_vhostHTTPPort="${input_port}"
        echo -e "${program_name} vhostHTTPPort: ${COLOR_YELOW}${set_vhostHTTPPort}${COLOR_END}"
        echo -e ""
        fun_input_vhostHTTPSPort
        [ -n "${input_port}" ] && set_vhostHTTPSPort="${input_port}"
        echo -e "${program_name} vhostHTTPSPort: ${COLOR_YELOW}${set_vhostHTTPSPort}${COLOR_END}"
        echo -e ""
        fun_input_webServerport
        [ -n "${input_port}" ] && set_webServerport="${input_port}"
        echo -e "${program_name} webServerport: ${COLOR_YELOW}${set_webServerport}${COLOR_END}"
        echo -e ""
        fun_input_webServeruser
        [ -n "${input_webServeruser}" ] && set_webServeruser="${input_webServeruser}"
        echo -e "${program_name} webServeruser: ${COLOR_YELOW}${set_webServeruser}${COLOR_END}"
        echo -e ""
        fun_input_webServerpassword
        [ -n "${input_webServerpassword}" ] && set_webServerpassword="${input_webServerpassword}"
        echo -e "${program_name} webServerpassword: ${COLOR_YELOW}${set_webServerpassword}${COLOR_END}"
        echo -e ""
        fun_input_token
        [ -n "${input_token}" ] && set_token="${input_token}"
        echo -e "${program_name} token: ${COLOR_YELOW}${set_token}${COLOR_END}"
        echo -e ""
        fun_input_subDomainHost
        [ -n "${input_subDomainHost}" ] && set_subDomainHost="${input_subDomainHost}"
        echo -e "${program_name} subDomainHost: ${COLOR_YELOW}${set_subDomainHost}${COLOR_END}"
        echo -e ""
        fun_input_transportmaxPoolCount
        [ -n "${input_number}" ] && set_transportmaxPoolCount="${input_number}"
        echo -e "${program_name} transportmaxPoolCount: ${COLOR_YELOW}${set_transportmaxPoolCount}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}loglevel${COLOR_END}"
        echo    "1: info (default)"
        echo    "2: warn"
        echo    "3: error"
        echo    "4: debug"    
		echo    "5: trace"
        echo    "-------------------------"
        read -e -p "Enter your choice (1, 2, 3, 4, 5 or exit. default [1]): " str_loglevel
        case "${str_loglevel}" in
            1|[Ii][Nn][Ff][Oo])
                str_loglevel="info"
                ;;
            2|[Ww][Aa][Rr][Nn])
                str_loglevel="warn"
                ;;
            3|[Ee][Rr][Rr][Oo][Rr])
                str_loglevel="error"
                ;;
            4|[Dd][Ee][Bb][Uu][Gg])
                str_loglevel="debug"
                ;;
			5|[Tt][Rr][Aa][Cc][Ee])
			    str_loglevel="trace"
				;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                str_loglevel="info"
                ;;
        esac
        echo -e "loglevel: ${COLOR_YELOW}${str_loglevel}${COLOR_END}"
        echo -e ""
        fun_input_logmaxDays
        [ -n "${input_number}" ] && set_logmaxDays="${input_number}"
        echo -e "${program_name} logmaxDays: ${COLOR_YELOW}${set_logmaxDays}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}logto${COLOR_END}"
        echo    "1: enable (default)"
        echo    "2: disable"
        echo "-------------------------"
        read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_logto
        case "${str_logto}" in
            1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                str_logto="./frps.log"
                str_logto_flag="enable"
                ;;
            0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                str_logto="/dev/null"
                str_logto_flag="disable"
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                str_logto="./frps.log"
                str_logto_flag="enable"
                ;;
        esac
        echo -e "logto: ${COLOR_YELOW}${str_logto_flag}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}transporttcpMux${COLOR_END}"
        echo    "1: enable (default)"
        echo    "2: disable"
        echo "-------------------------"         
        read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_transporttcpMux
        case "${str_transporttcpMux}" in
            1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                set_transporttcpMux="true"
                ;;
            0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                set_transporttcpMux="false"
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                set_transporttcpMux="true"
                ;;
        esac
        echo -e "transporttcpMux: ${COLOR_YELOW}${set_transporttcpMux}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}transport_protocol${COLOR_END}"
        echo "1: kcp"
        echo "2: quic (default)"
        echo "-------------------------"
        read -e -p "Enter your choice (1, 2 or exit. default [2]): " str_transport_protocol
        case "${transport_protocol}" in
            1|[kK][cC][pP]) set_transport_protocol="kcp" ;;
            2|[qQ][uU][iI][cC]|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE]) set_transport_protocol="quic" ;;
              [eE][xX][iI][tT]) exit 1 ;;
            *) set_transport_protocol="quic"
                ;;
        esac
        echo -e "transport_protocol: ${COLOR_YELOW}${set_transport_protocol}${COLOR_END}"
        echo -e ""

        echo "============== Check your input =============="
        echo -e "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e "Bind port          : ${COLOR_GREEN}${set_bindPort}${COLOR_END}"
        echo -e "vhost http port    : ${COLOR_GREEN}${set_vhostHTTPPort}${COLOR_END}"
        echo -e "vhost https port   : ${COLOR_GREEN}${set_vhostHTTPSPort}${COLOR_END}"
        echo -e "Dashboard port     : ${COLOR_GREEN}${set_webServerport}${COLOR_END}"
        echo -e "Dashboard user     : ${COLOR_GREEN}${set_webServeruser}${COLOR_END}"
        echo -e "Dashboard password : ${COLOR_GREEN}${set_webServerpassword}${COLOR_END}"
        echo -e "token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
        echo -e "subDomainHost      : ${COLOR_GREEN}${set_subDomainHost}${COLOR_END}"
		echo -e "Transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
        echo -e "TransporttcpMux    : ${COLOR_GREEN}${set_transporttcpMux}${COLOR_END}"
        echo -e "Max Pool count     : ${COLOR_GREEN}${set_transportmaxPoolCount}${COLOR_END}"
        echo -e "Log level          : ${COLOR_GREEN}${str_loglevel}${COLOR_END}"
        echo -e "Log max days       : ${COLOR_GREEN}${set_logmaxDays}${COLOR_END}"
        echo -e "Log file           : ${COLOR_GREEN}${str_logto_flag}${COLOR_END}"
        echo "=============================================="
        echo ""
        echo "Press any key to start...or Press Ctrl+c to cancel"

        char=`get_char`
        install_program_server_frps
    fi
}
# ====== install server ======
install_program_server_frps(){
    [ ! -d ${str_program_dir} ] && mkdir -p ${str_program_dir}
    cd ${str_program_dir}
    echo "${program_name} install path:$PWD"

    echo -n "config file for ${program_name} ..."
# Config file
if [[ "${set_transport_protocol}" == "kcp" ]]; then
cat <<- EOF >> "${str_program_dir}/${program_config_file}.toml"
# This configuration file is for reference only. Please do not use this configuration directly to run the program as it may have various issues.
# A literal address or host name for IPv6 must be enclosed
# in square brackets, as in "[::1]:80", "[ipv6-host]:http" or "[ipv6-host%zone]:80"
# For single "bindAddr" field, no need square brackets, like `bindAddr = "::"`.
bindAddr = "0.0.0.0"
bindPort = ${set_bindPort}

# udp port used for kcp protocol, it can be same with 'bindPort'.
# if not set, kcp is disabled in frps.
kcpBindPort = ${set_bindPort}

# udp port used for quic protocol.
# if not set, quic is disabled in frps.
# quicBindPort = ${set_bindPort}

# Specify which address proxy will listen for, default value is same with bindAddr
# proxyBindAddr = "127.0.0.1"

# quic protocol options
# transport.quic.keepalivePeriod = 10
# transport.quic.maxIdleTimeout = 30
# transport.quic.maxIncomingStreams = 100000

# Heartbeat configure, it's not recommended to modify the default value
# The default value of heartbeatTimeout is 90. Set negative value to disable it.
# transport.heartbeatTimeout = 90

# Pool count in each proxy will keep no more than maxPoolCount.
transport.maxPoolCount = ${set_transportmaxPoolCount}

# If tcp stream multiplexing is used, default is true
transport.tcpMux = ${set_transporttcpMux}

# Specify keep alive interval for tcp mux.
# only valid if tcpMux is true.
# transport.tcpMuxKeepaliveInterval = 30

# tcpKeepalive specifies the interval between keep-alive probes for an active network connection between frpc and frps.
# If negative, keep-alive probes are disabled.
# transport.tcpKeepalive = 7200

# transport.tls.force specifies whether to only accept TLS-encrypted connections. By default, the value is false.
transport.tls.force = false

# transport.tls.certFile = "server.crt"
# transport.tls.keyFile = "server.key"
# transport.tls.trustedCaFile = "ca.crt"

# If you want to support virtual host, you must set the http port for listening (optional)
# Note: http port and https port can be same with bindPort
vhostHTTPPort = ${set_vhostHTTPPort}
vhostHTTPSPort = ${set_vhostHTTPSPort}

# Response header timeout(seconds) for vhost http server, default is 60s
# vhostHTTPTimeout = 60

# tcpmuxHTTPConnectPort specifies the port that the server listens for TCP
# HTTP CONNECT requests. If the value is 0, the server will not multiplex TCP
# requests on one single port. If it's not - it will listen on this value for
# HTTP CONNECT requests. By default, this value is 0.
# tcpmuxHTTPConnectPort = 1337

# If tcpmuxPassthrough is true, frps won't do any update on traffic.
# tcpmuxPassthrough = false

# Configure the web server to enable the dashboard for frps.
# dashboard is available only if webServerport is set.
webServer.addr = "0.0.0.0"
webServer.port = ${set_webServerport}
webServer.user = ${set_webServeruser}
webServer.password = ${set_webServerpassword}
# webServer.tls.certFile = "server.crt"
# webServer.tls.keyFile = "server.key"
# dashboard assets directory(only for debug mode)
# webServer.assetsDir = "./static"

# Enable golang pprof handlers in dashboard listener.
# Dashboard port must be set first
webServer.pprofEnable = false

# enablePrometheus will export prometheus metrics on webServer in /metrics api.
enablePrometheus = true

# console or real logFile path like ./frps.log
log.to = ${str_logto_flag}
# trace, debug, info, warn, error
log.level = ${str_loglevel}
log.maxDays = ${set_logmaxDays}
# disable log colors when log.to is console, default is false
log.disablePrintColor = false

# DetailedErrorsToClient defines whether to send the specific error (with debug info) to frpc. By default, this value is true.
detailedErrorsToClient = true

# auth.method specifies what authentication method to use authenticate frpc with frps.
# If "token" is specified - token will be read into login message.
# If "oidc" is specified - OIDC (Open ID Connect) token will be issued using OIDC settings. By default, this value is "token".
auth.method = "token"

# auth.additionalScopes specifies additional scopes to include authentication information.
# Optional values are HeartBeats, NewWorkConns.
# auth.additionalScopes = ["HeartBeats", "NewWorkConns"]

# auth token
auth.token = ${set_token}

# userConnTimeout specifies the maximum time to wait for a work connection.
# userConnTimeout = 10

# Max ports can be used for each client, default value is 0 means no limit
maxPortsPerClient = 0

# If subDomainHost is not empty, you can set subdomain when type is http or https in frpc's configure file
# When subdomain is test, the host used by routing is test.frps.com
subDomainHost = ${set_subDomainHost}

# custom 404 page for HTTP requests
# custom404Page = "/path/to/404.html"

# specify udp packet size, unit is byte. If not set, the default value is 1500.
# This parameter should be same between client and server.
# It affects the udp and sudp proxy.
udpPacketSize = 1500

# Retention time for NAT hole punching strategy data.
natholeAnalysisDataReserveHours = 168

# ssh tunnel gateway
# If you want to enable this feature, the bindPort parameter is required, while others are optional.
# By default, this feature is disabled. It will be enabled if bindPort is greater than 0.
# sshTunnelGateway.bindPort = 2200
# sshTunnelGateway.privateKeyFile = "/home/frp-user/.ssh/id_rsa"
# sshTunnelGateway.autoGenPrivateKeyPath = ""
# sshTunnelGateway.authorizedKeysFile = "/home/frp-user/.ssh/authorized_keys"
EOF
else
cat <<- EOF >> "${str_program_dir}/${program_config_file}.toml"
# This configuration file is for reference only. Please do not use this configuration directly to run the program as it may have various issues.
# A literal address or host name for IPv6 must be enclosed
# in square brackets, as in "[::1]:80", "[ipv6-host]:http" or "[ipv6-host%zone]:80"
# For single "bindAddr" field, no need square brackets, like `bindAddr = "::"`.
bindAddr = "0.0.0.0"
bindPort = ${set_bindPort}

# udp port used for kcp protocol, it can be same with 'bindPort'.
# if not set, kcp is disabled in frps.
# kcpBindPort = ${set_bindPort}

# udp port used for quic protocol.
# if not set, quic is disabled in frps.
quicBindPort = ${set_bindPort}

# Specify which address proxy will listen for, default value is same with bindAddr
# proxyBindAddr = "127.0.0.1"

# quic protocol options
# transport.quic.keepalivePeriod = 10
# transport.quic.maxIdleTimeout = 30
# transport.quic.maxIncomingStreams = 100000

# Heartbeat configure, it's not recommended to modify the default value
# The default value of heartbeatTimeout is 90. Set negative value to disable it.
# transport.heartbeatTimeout = 90

# Pool count in each proxy will keep no more than maxPoolCount.
transport.maxPoolCount = ${set_transportmaxPoolCount}

# If tcp stream multiplexing is used, default is true
transport.tcpMux = ${set_transporttcpMux}

# Specify keep alive interval for tcp mux.
# only valid if tcpMux is true.
# transport.tcpMuxKeepaliveInterval = 30

# tcpKeepalive specifies the interval between keep-alive probes for an active network connection between frpc and frps.
# If negative, keep-alive probes are disabled.
# transport.tcpKeepalive = 7200

# transport.tls.force specifies whether to only accept TLS-encrypted connections. By default, the value is false.
transport.tls.force = false

# transport.tls.certFile = "server.crt"
# transport.tls.keyFile = "server.key"
# transport.tls.trustedCaFile = "ca.crt"

# If you want to support virtual host, you must set the http port for listening (optional)
# Note: http port and https port can be same with bindPort
vhostHTTPPort = ${set_vhostHTTPPort}
vhostHTTPSPort = ${set_vhostHTTPSPort}

# Response header timeout(seconds) for vhost http server, default is 60s
# vhostHTTPTimeout = 60

# tcpmuxHTTPConnectPort specifies the port that the server listens for TCP
# HTTP CONNECT requests. If the value is 0, the server will not multiplex TCP
# requests on one single port. If it's not - it will listen on this value for
# HTTP CONNECT requests. By default, this value is 0.
# tcpmuxHTTPConnectPort = 1337

# If tcpmuxPassthrough is true, frps won't do any update on traffic.
# tcpmuxPassthrough = false

# Configure the web server to enable the dashboard for frps.
# dashboard is available only if webServerport is set.
webServer.addr = 0.0.0.0
webServer.port = ${set_webServerport}
webServer.user = ${set_webServeruser}
webServer.password = ${set_webServerpassword}
# webServer.tls.certFile = "server.crt"
# webServer.tls.keyFile = "server.key"
# dashboard assets directory(only for debug mode)
# webServer.assetsDir = "./static"

# Enable golang pprof handlers in dashboard listener.
# Dashboard port must be set first
webServer.pprofEnable = false

# enablePrometheus will export prometheus metrics on webServer in /metrics api.
enablePrometheus = true

# console or real logFile path like ./frps.log
log.to = ${str_logto_flag}
# trace, debug, info, warn, error
log.level = ${str_loglevel}
log.maxDays = ${set_logmaxDays}
# disable log colors when log.to is console, default is false
log.disablePrintColor = false

# DetailedErrorsToClient defines whether to send the specific error (with debug info) to frpc. By default, this value is true.
detailedErrorsToClient = true

# auth.method specifies what authentication method to use authenticate frpc with frps.
# If "token" is specified - token will be read into login message.
# If "oidc" is specified - OIDC (Open ID Connect) token will be issued using OIDC settings. By default, this value is "token".
auth.method = "token"

# auth.additionalScopes specifies additional scopes to include authentication information.
# Optional values are HeartBeats, NewWorkConns.
# auth.additionalScopes = ["HeartBeats", "NewWorkConns"]

# auth token
auth.token = ${set_token}

# userConnTimeout specifies the maximum time to wait for a work connection.
# userConnTimeout = 10

# Max ports can be used for each client, default value is 0 means no limit
maxPortsPerClient = 0

# If subDomainHost is not empty, you can set subdomain when type is http or https in frpc's configure file
# When subdomain is test, the host used by routing is test.frps.com
subDomainHost = ${set_subDomainHost}

# custom 404 page for HTTP requests
# custom404Page = "/path/to/404.html"

# specify udp packet size, unit is byte. If not set, the default value is 1500.
# This parameter should be same between client and server.
# It affects the udp and sudp proxy.
udpPacketSize = 1500

# Retention time for NAT hole punching strategy data.
natholeAnalysisDataReserveHours = 168

# ssh tunnel gateway
# If you want to enable this feature, the bindPort parameter is required, while others are optional.
# By default, this feature is disabled. It will be enabled if bindPort is greater than 0.
# sshTunnelGateway.bindPort = 2200
# sshTunnelGateway.privateKeyFile = "/home/frp-user/.ssh/id_rsa"
# sshTunnelGateway.autoGenPrivateKeyPath = ""
# sshTunnelGateway.authorizedKeysFile = "/home/frp-user/.ssh/authorized_keys"
EOF
fi
    echo " done"

    echo -n "download ${program_name} ..."
    rm -f ${str_program_dir}/${program_name} ${program_init}
    fun_download_file
    echo " done"
    echo -n "download ${program_init}..."
    if [ ! -s ${program_init} ]; then
        if ! wget  -q ${FRPS_INIT} -O ${program_init}; then
            echo -e " ${COLOR_RED}failed${COLOR_END}"
            exit 1
        fi
    fi
    [ ! -x ${program_init} ] && chmod +x ${program_init}
    echo " done"

    echo -n "setting ${program_name} boot..."
    [ ! -x ${program_init} ] && chmod +x ${program_init}
    if [ "${OS}" == 'CentOS' ]; then
        chmod +x ${program_init}
        chkconfig --add ${program_name}
    else
        chmod +x ${program_init}
        update-rc.d -f ${program_name} defaults
    fi
    echo " done"
    [ -s ${program_init} ] && ln -s ${program_init} /usr/bin/${program_name}
    ${program_init} start
    fun_frps
    #install successfully
    echo ""
    echo "Congratulations, ${program_name} install completed!"
    echo "================================================"
    echo -e "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "Bind port          : ${COLOR_GREEN}${set_bindPort}${COLOR_END}"
    echo -e "Transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
    echo -e "vhost http port    : ${COLOR_GREEN}${set_vhostHTTPPort}${COLOR_END}"
    echo -e "vhost https port   : ${COLOR_GREEN}${set_vhostHTTPSPort}${COLOR_END}"
    echo -e "Dashboard port     : ${COLOR_GREEN}${set_webServerport}${COLOR_END}"
    echo -e "token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
    echo -e "subDomainHost      : ${COLOR_GREEN}${set_subDomainHost}${COLOR_END}"
    echo -e "TransporttcpMux    : ${COLOR_GREEN}${set_transporttcpMux}${COLOR_END}"
    echo -e "Max Pool count     : ${COLOR_GREEN}${set_transportmaxPoolCount}${COLOR_END}"
    echo -e "Log level          : ${COLOR_GREEN}${str_loglevel}${COLOR_END}"
    echo -e "Log max days       : ${COLOR_GREEN}${set_logmaxDays}${COLOR_END}"
    echo -e "Log file           : ${COLOR_GREEN}${str_logto_flag}${COLOR_END}"
    echo "================================================"
    echo -e "${program_name} Dashboard     : ${COLOR_GREEN}http://${set_subDomainHost}:${set_webServerport}/${COLOR_END}"
    echo -e "Dashboard user     : ${COLOR_GREEN}${set_webServeruser}${COLOR_END}"
    echo -e "Dashboard password : ${COLOR_GREEN}${set_webServerpassword}${COLOR_END}"
    echo "================================================"
    echo ""
    echo -e "${program_name} status manage : ${COLOR_PINKBACK_WHITEFONT}${program_name}${COLOR_END} {${COLOR_GREEN}start|stop|restart|status|config|version${COLOR_END}}"
    echo -e "Example:"
    echo -e "  start: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}start${COLOR_END}"
    echo -e "  stop: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}stop${COLOR_END}"
    echo -e "restart: ${COLOR_PINK}${program_name}${COLOR_END} ${COLOR_GREEN}restart${COLOR_END}"
    exit 0
}
############################### configure ##################################
configure_program_server_frps(){
    if [ -s ${str_program_dir}/${program_config_file} ]; then
        vi ${str_program_dir}/${program_config_file}
    else
        echo "${program_name} configuration file not found!"
        exit 1
    fi
}
############################### uninstall ##################################
uninstall_program_server_frps(){
    fun_frps
    if [ -s ${program_init} ] || [ -s ${str_program_dir}/${program_name} ] ; then
        echo "============== Uninstall ${program_name} =============="
        str_uninstall="n"
        echo -n -e "${COLOR_YELOW}You want to uninstall?${COLOR_END}"
        read -e -p "[Y/N]:" str_uninstall
        case "${str_uninstall}" in
        [yY]|[yY][eE][sS])
        echo ""
        echo "You select [Yes], press any key to continue."
        str_uninstall="y"
        char=`get_char`
        ;;
        *)
        echo ""
        str_uninstall="n"
        esac
        if [ "${str_uninstall}" == 'n' ]; then
            echo "You select [No],shell exit!"
        else
            checkos
            ${program_init} stop
            if [ "${OS}" == 'CentOS' ]; then
                chkconfig --del ${program_name}
            else
                update-rc.d -f ${program_name} remove
            fi
            rm -f ${program_init} /var/run/${program_name}.pid /usr/bin/${program_name}
            rm -fr ${str_program_dir}
            echo "${program_name} uninstall success!"
        fi
    else
        echo "${program_name} Not install!"
    fi
    exit 0
}
############################### update ##################################
update_config_frps(){
    if [ ! -r "${str_program_dir}/${program_config_file}" ]; then
        echo "config file ${str_program_dir}/${program_config_file} not found."
    else
        search_webServeruser=`grep "webServeruser" ${str_program_dir}/${program_config_file}`
        search_webServerpassword=`grep "webServerpassword" ${str_program_dir}/${program_config_file}`
        search_kcpBindPort=`grep "kcpBindPort" ${str_program_dir}/${program_config_file}`
		search_quicBindPort=`grep "quicBindPort" ${str_program_dir}/${program_config_file}`
        search_transporttcpMux=`grep "transporttcpMux" ${str_program_dir}/${program_config_file}`
        search_token=`grep "privilege_token" ${str_program_dir}/${program_config_file}`
        search_allow_ports=`grep "privilege_allow_ports" ${str_program_dir}/${program_config_file}`
        if [ -z "${search_webServeruser}" ] || [ -z "${search_webServerpassword}" ] || [ -z "${search_kcpBindPort}" ] || [ -z "${search_quicbindPort}" ] || [ -z "${search_transporttcpMux}" ] || [ ! -z "${search_token}" ] || [ ! -z "${search_allow_ports}" ];then
            echo -e "${COLOR_GREEN}Configuration files need to be updated, now setting:${COLOR_END}"
            echo ""
            if [ ! -z "${search_token}" ];then
                sed -i "s/privilege_token/token/" ${str_program_dir}/${program_config_file}
            fi
            if [ -z "${search_webServeruser}" ] && [ -z "${search_webServerpassword}" ];then
                def_webServeruser_update="admin"
                read -e -p "Please input webServeruser (Default: ${def_webServeruser_update}):" set_webServeruser_update
                [ -z "${set_webServeruser_update}" ] && set_webServeruser_update="${def_webServeruser_update}"
                echo "${program_name} webServeruser: ${set_webServeruser_update}"
                echo ""
                def_webServerpassword_update=`fun_randstr 8`
                read -e -p "Please input webServerpassword (Default: ${def_webServerpassword_update}):" set_webServerpassword_update
                [ -z "${set_webServerpassword_update}" ] && set_webServerpassword_update="${def_webServerpassword_update}"
                echo "${program_name} webServerpassword: ${set_webServerpassword_update}"
                echo ""
                sed -i "/webServerport =.*/a\webServeruser = ${set_webServeruser_update}\nwebServerpassword = ${set_webServerpassword_update}\n" ${str_program_dir}/${program_config_file}
            fi
            if [ -z "${search_transport_protocol}" ];then 
                echo -e "Please select ${COLOR_GREEN}transport_protocol${COLOR_END}"
                echo "1: kcp"
                echo "2: quic (default)"
                echo "-------------------------"
                read -e -p "Enter your choice (1, 2 or exit. default [2]): " str_transport_protocol
                case "${transport_protocol}" in
                1|[kK][cC][pP]) set_transport_protocol="kcp" ;;
                2|[qQ][uU][iI][cC]|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE]) set_transport_protocol="quic" ;;
                  [eE][xX][iI][tT]) exit 1 ;;
                *) set_transport_protocol="quic"
                ;;
                esac
                echo "transport_protocol: ${set_transport_protocol}"
                def_kcpBindPort=( $( __readINI ${str_program_dir}/${program_config_file} common bindPort ) )
                if [[ "${set_transport_protocol}" == "kcp" ]]; then
                    sed -i "/^bindPort =.*/a\# tcp port used for transport_protocol, it can be same with 'bindPort'\n# if not set, kcp is disabled in frps\n#kcpBindPort = ${def_kcpBindPort}\n" ${str_program_dir}/${program_config_file}
                else
                    sed -i "/^bindPort =.*/a\# udp port used for transport_protocol, it can be same with 'bindPort'\n# if not set, quic is disabled in frps\nquicBindPort = ${def_quicBindPort}\n" ${str_program_dir}/${program_config_file}
                fi
            fi
            if [ -z "${search_transporttcpMux}" ];then
                echo "# Please select transporttcpMux "
                echo "1: enable (default)"
                echo "2: disable"
                echo "-------------------------"  
                read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_transporttcpMux
                case "${str_transporttcpMux}" in
                    1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                        set_transporttcpMux="true"
                        ;;
                    0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                        set_transporttcpMux="false"
                        ;;
                    [eE][xX][iI][tT])
                        exit 1
                        ;;
                    *)
                        set_transporttcpMux="true"
                        ;;
                esac
                echo "transporttcpMux: ${set_transporttcpMux}"
                sed -i "/^privilege_mode = true/d" ${str_program_dir}/${program_config_file}
                sed -i "/^token =.*/a\# if tcp stream multiplexing is used, default is true\ntransporttcpMux = ${set_transporttcpMux}\n" ${str_program_dir}/${program_config_file}
            fi
            if [ ! -z "${search_allow_ports}" ];then
                sed -i "s/privilege_allow_ports/allow_ports/" ${str_program_dir}/${program_config_file}
            fi
        fi
        verify_webServeruser=`grep "^webServeruser" ${str_program_dir}/${program_config_file}`
        verify_webServerpassword=`grep "^webServerpassword" ${str_program_dir}/${program_config_file}`
        verify_kcpBindPort=`grep "kcpBindPort" ${str_program_dir}/${program_config_file}`
        verify_quicBindPort=`grep "quicBindPort" ${str_program_dir}/${program_config_file}`
        verify_transporttcpMux=`grep "^transporttcpMux" ${str_program_dir}/${program_config_file}`
        verify_token=`grep "privilege_token" ${str_program_dir}/${program_config_file}`
        verify_allow_ports=`grep "privilege_allow_ports" ${str_program_dir}/${program_config_file}`
        if [ ! -z "${verify_webServeruser}" ] && [ ! -z "${verify_webServerpassword}" ] && [ ! -z "${verify_kcpBindPort}" ] && [ ! -z "${verify_quicBindPort}" ] && [ ! -z "${verify_transporttcpMux}" ] && [ -z "${verify_token}" ] && [ -z "${verify_allow_ports}" ];then
            echo -e "${COLOR_GREEN}update configuration file successfully!!!${COLOR_END}"
        else
            echo -e "${COLOR_RED}update configuration file error!!!${COLOR_END}"
        fi
    fi
}
update_program_server_frps() {
    fun_frps "clear"

    if [ -s "$program_init" ] || [ -s "$str_program_dir/$program_name" ]; then
        echo "============== Update $program_name =============="
        update_config_frps
        checkos
        check_centosversion
        check_os_bit
        fun_getVer

        remote_init_version=$(wget -qO- "$FRPS_INIT" | sed -n '/^version/p' | cut -d\" -f2)
        local_init_version=$(sed -n '/^version/p' "$program_init" | cut -d\" -f2)
        install_shell="$strPath"

        if [ -n "$remote_init_version" ]; then
            if [ "$local_init_version" != "$remote_init_version" ]; then
                echo "========== Update $program_name $program_init =========="
                if ! wget "$FRPS_INIT" -O "$program_init"; then
                    echo "Failed to download $program_name.init file!"
                    exit 1
                else
                    echo -e "${COLOR_GREEN}${program_init} Update successfully !!!${COLOR_END}"
                fi
            fi
        fi

        [ ! -d "$str_program_dir" ] && mkdir -p "$str_program_dir"
        echo -e "Loading network version for $program_name, please wait..."
        fun_getServer
        fun_getVer >/dev/null 2>&1
        local_program_version="$($str_program_dir/$program_name --version)"
        echo -e "${COLOR_GREEN}$program_name local version $local_program_version${COLOR_END}"
        echo -e "${COLOR_GREEN}$program_name remote version $FRPS_VER${COLOR_END}"

        if [ "$local_program_version" != "$FRPS_VER" ]; then
            echo -e "${COLOR_GREEN}Found a new version, update now!!!${COLOR_END}"
            "$program_init" stop
            sleep 1
            rm -f /usr/bin/$program_name "$str_program_dir/$program_name"
            fun_download_file

            if [ "$OS" == 'CentOS' ]; then
                chmod +x "$program_init"
                chkconfig --add "$program_name"
            else
                chmod +x "$program_init"
                update-rc.d -f "$program_name" defaults
            fi

            [ -s "$program_init" ] && ln -s "$program_init" /usr/bin/$program_name
            [ ! -x "$program_init" ] && chmod 755 "$program_init"
            "$program_init" start
            echo "$program_name version $($str_program_dir/$program_name --version)"
            echo "$program_name update success!"
        else
            echo -e "no need to update !!!${COLOR_END}"
        fi
    else
        echo "$program_name Not install!"
    fi
    exit 0
}

clear
strPath=$(pwd)
rootness
fun_set_text_color
checkos
check_centosversion
check_os_bit
pre_install_packs
shell_update

# Initialization
action=$1
if [ -z "$action" ]; then
    fun_frps
    echo "Arguments error! [$action ]"
    echo "Usage: $(basename "$0") {install|uninstall|update|config}"
    RET_VAL=1
else
    case "$action" in
    install)
        pre_install_frps 2>&1 | tee /root/${program_name}-install.log
        ;;
    config)
        configure_program_server_frps
        ;;
    uninstall)
        uninstall_program_server_frps 2>&1 | tee /root/${program_name}-uninstall.log
        ;;
    update)
        update_program_server_frps 2>&1 | tee /root/${program_name}-update.log
        ;;
    *)
        fun_frps
        echo "Arguments error! [$action ]"
        echo "Usage: $(basename "$0") {install|uninstall|update|config}"
        RET_VAL=1
        ;;
    esac
fi
