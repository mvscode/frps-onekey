#!/bin/bash

# Set the PATH variable
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Set environment variables
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

# Function to check for shell updates
shell_update() {
    # Clear the terminal
    fun_frps "clear"

    # Echo a message to indicate that we're checking for shell updates
    echo "Checking for shell updates..."

    # Fetch the remote shell version from the specified URL
    remote_shell_version=$(wget --no-check-certificate -qO- "${str_install_shell}" | sed -n '/^version/p' | cut -d'"' -f2)

	# Check if the local version is lower than the remote version
	if [[ "${version}" < "${remote_shell_version}" ]]; then
	# Echo a message to indicate that a new version has been found
	echo -e "${COLOR_YELOW}Found a newer version!${COLOR_END}"
	echo
	# Echo the local and remote versions
	echo -e "${COLOR_BLUE}Local version: ${version}${COLOR_END}"
	echo -e "${COLOR_GREEN}Remote version: ${remote_shell_version}${COLOR_END}"
	echo
	# Ask user if they need to update
	read -p "Update the latest script version? [y/N] " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo

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
		echo -e "${COLOR_GREEN}Please re-run${COLOR_END} ${COLOR_PINK}$0 ${frps_action}${COLOR_END}"
		echo
		exit 1
	fi
    else
	# If user chooses not to update, continue with the script
	    echo
	    echo -e "${COLOR_YELOW}Continuing with the current script...${COLOR_END}"
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
    echo "|    frps for Linux Server, Author Clang, Mender MvsCode     |" 
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
# Check Server OS
checkos(){
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
        echo "Unsupported OS. Please use a supported Linux distribution and retry!"
        exit 1
    fi
}
# Get version
getversion(){
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
# Check server os version
check_os_version(){
    local required_version=$1
    local current_version=$(getversion)
    
    if [[ "$(echo -e "$current_version\n$required_version" | sort -V | head -n1)" == "$required_version" ]]; then
        return 0  # when current version > required version
    else
        return 1  # when current version < required version
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
    echo -e "Please select ${COLOR_PINK}${program_name} download${COLOR_END} url:"
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
	echo -e "Downloading ${program_name}..."
	echo ""
        curl -L --progress-bar "${program_latest_file_url}" -o "${program_latest_filename}" 2>&1 | show_progress
	echo ""		
	if [ $? -ne 0 ]; then
        echo -e " ${COLOR_RED}Download failed${COLOR_END}"
	exit 1
    fi
	
    # Verify the downloaded file exists and is not empty
    if [ ! -s ${program_latest_filename} ]; then
      echo -e " ${COLOR_RED}Downloaded file is empty or not found${COLOR_END}"
      exit 1
    fi		
      echo -e "Extracting ${program_name}..."
      echo ""
	  
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
# Helper function to format the progress bar
show_progress() {
  local TOTAL_SIZE=1000000  # Assume total size is 1000000 bytes
  local CURRENT_SIZE=0   # Initial download size is 0 bytes
  local GREEN='\033[1;32m'
  local NC='\033[0m'  # No Color

  while [ $CURRENT_SIZE -lt $TOTAL_SIZE ] || [ $PERCENTAGE -lt 100 ]; do
    PERCENTAGE=$(awk "BEGIN {printf \"%.0f\", $CURRENT_SIZE*100/$TOTAL_SIZE}")

    if ! [[ "$PERCENTAGE" =~ ^[0-9]+$ ]] ; then
      PERCENTAGE=0
    fi

    local completed=$((PERCENTAGE / 2))
    local remaining=$((50 - completed))

    if [ $PERCENTAGE -eq 100 ]; then
      completed=50
      remaining=0
    fi

    printf "\r${GREEN}%2d%% [" "$PERCENTAGE"
    for ((i = 0; i < completed; i++)); do
     if [ $i -eq $((completed - 1)) ]; then
      printf ">"
     else
      printf "="
     fi
    done
    for ((i = 0; i < remaining; i++)); do
      printf " "
    done
      printf "]${NC}"

    CURRENT_SIZE=$((CURRENT_SIZE + $((RANDOM % 50000 + 1))))
    sleep 0.05
  done

  echo -e "\nDownload complete!"
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
        checkServerPort=`netstat -ntulp | grep "\b:${strCheckPort}\b"`
        if [ -n "${checkServerPort}" ]; then
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
fun_input_bind_port(){
    def_server_port="5443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default Server Port: ${def_server_port}):" serverport
    [ -z "${serverport}" ] && serverport="${def_server_port}"
    fun_check_port "bind" "${serverport}"
}
fun_input_dashboard_port(){
    def_dashboard_port="6443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_dashboard_port}):" input_dashboard_port
    [ -z "${input_dashboard_port}" ] && input_dashboard_port="${def_dashboard_port}"
    fun_check_port "dashboard" "${input_dashboard_port}"
}
fun_input_vhost_http_port(){
    def_vhost_http_port="80"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_http_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhost_http_port}):" input_vhost_http_port
    [ -z "${input_vhost_http_port}" ] && input_vhost_http_port="${def_vhost_http_port}"
    fun_check_port "vhost_http" "${input_vhost_http_port}"
}
fun_input_vhost_https_port(){
    def_vhost_https_port="443"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}vhost_https_port${COLOR_END} [1-65535]"
    read -e -p "(Default : ${def_vhost_https_port}):" input_vhost_https_port
    [ -z "${input_vhost_https_port}" ] && input_vhost_https_port="${def_vhost_https_port}"
    fun_check_port "vhost_https" "${input_vhost_https_port}"
}
fun_input_log_max_days(){
    def_max_days="15" 
    def_log_max_days="3"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}log_max_days${COLOR_END} [1-${def_max_days}]"
    read -e -p "(Default : ${def_log_max_days} day):" input_log_max_days
    [ -z "${input_log_max_days}" ] && input_log_max_days="${def_log_max_days}"
    fun_check_number "log_max_days" "${def_max_days}" "${input_log_max_days}"
}
fun_input_max_pool_count(){
    def_max_pool="50"
    def_max_pool_count="5"
    echo ""
    echo -e "Please input ${program_name} ${COLOR_GREEN}max_pool_count${COLOR_END} [1-${def_max_pool}]"
    read -e -p "(Default : ${def_max_pool_count}):" input_max_pool_count
    [ -z "${input_max_pool_count}" ] && input_max_pool_count="${def_max_pool_count}"
    fun_check_number "max_pool_count" "${def_max_pool}" "${input_max_pool_count}"
}
fun_input_dashboard_user(){
    def_dashboard_user="admin"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_user${COLOR_END}"
    read -e -p "(Default : ${def_dashboard_user}):" input_dashboard_user
    [ -z "${input_dashboard_user}" ] && input_dashboard_user="${def_dashboard_user}"
}
fun_input_dashboard_pwd(){
    def_dashboard_pwd=`fun_randstr 8`
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}dashboard_pwd${COLOR_END}"
    read -e -p "(Default : ${def_dashboard_pwd}):" input_dashboard_pwd
    [ -z "${input_dashboard_pwd}" ] && input_dashboard_pwd="${def_dashboard_pwd}"
}
fun_input_token(){
    def_token=`fun_randstr 16`
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}token${COLOR_END}"
    read -e -p "(Default : ${def_token}):" input_token
    [ -z "${input_token}" ] && input_token="${def_token}"
}
fun_input_subdomain_host(){
    def_subdomain_host=${defIP}
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}subdomain_host${COLOR_END}"
    read -e -p "(Default : ${def_subdomain_host}):" input_subdomain_host
    [ -z "${input_subdomain_host}" ] && input_subdomain_host="${def_subdomain_host}"
}
fun_input_kcp_bind_port(){
    def_kcp_bind_port="${serverport}"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}kcp_bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default kcp bind port: ${def_kcp_bind_port}):" input_kcp_bind_port
    [ -z "${input_kcp_bind_port}" ] && input_kcp_bind_port="${def_kcp_bind_port}"
    fun_check_port "input_kcp_bind_port" "${input_kcp_bind_port}"
}
fun_input_quic_bind_port(){
    def_quic_bind_port="${input_vhost_https_port}"
    echo ""
    echo -n -e "Please input ${program_name} ${COLOR_GREEN}quic_bind_port${COLOR_END} [1-65535]"
    read -e -p "(Default quic bind port: ${def_quic_bind_port}):" input_quic_bind_port
    [ -z "${input_quic_bind_port}" ] && input_quic_bind_port="${def_quic_bind_port}"
    fun_check_port "input_quic_bind_port" "${input_quic_bind_port}"
}
pre_install_frps(){
    fun_frps
    echo -e "Check your server setting, please wait..."
	echo ""
    disable_selinux

    # Check if the frps service is already running
    if pgrep -x "${program_name}" >/dev/null; then
    echo -e "${COLOR_GREEN}${program_name} is already installed and running.${COLOR_END}"
else
    echo -e "${COLOR_YELOW}${program_name} is not running or not install.${COLOR_END}"
    echo ""
    read -p "Do you want to re-install ${program_name}? (y/n) " choice
	echo ""
    case "$choice" in
      y|Y)
        echo -e "${COLOR_GREEN} Re-installing ${program_name}...${COLOR_END}"
        ;;
      n|N)
        echo -e "${COLOR_YELOW} Skipping installation.${COLOR_END}"
		echo ""
		exit 1
        ;;
      *)
        echo -e "${COLOR_YELOW}Invalid choice. Skipping installation. ${COLOR_END}"
		echo ""
		exit 1
        ;;
    esac
        clear
        fun_frps
        fun_getServer
        fun_getVer
        echo -e ""
        echo -e "Loading You Server IP, please wait..."
        defIP=$(curl -s https://api.ipify.org)
        echo -e "You Server IP:${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e ""
        echo -e "————————————————————————————————————————————"
        echo -e "     ${COLOR_RED}Please input your server setting:${COLOR_END}"
        echo -e "————————————————————————————————————————————"
        fun_input_bind_port
        [ -n "${input_port}" ] && set_bind_port="${input_port}"
        echo -e "${program_name} bind_port: ${COLOR_YELOW}${set_bind_port}${COLOR_END}"
        echo -e ""
        fun_input_vhost_http_port
        [ -n "${input_port}" ] && set_vhost_http_port="${input_port}"
        echo -e "${program_name} vhost_http_port: ${COLOR_YELOW}${set_vhost_http_port}${COLOR_END}"
        echo -e ""
        fun_input_vhost_https_port
        [ -n "${input_port}" ] && set_vhost_https_port="${input_port}"
        echo -e "${program_name} vhost_https_port: ${COLOR_YELOW}${set_vhost_https_port}${COLOR_END}"
        echo -e ""
        fun_input_dashboard_port
        [ -n "${input_port}" ] && set_dashboard_port="${input_port}"
        echo -e "${program_name} dashboard_port: ${COLOR_YELOW}${set_dashboard_port}${COLOR_END}"
        echo -e ""
        fun_input_dashboard_user
        [ -n "${input_dashboard_user}" ] && set_dashboard_user="${input_dashboard_user}"
        echo -e "${program_name} dashboard_user: ${COLOR_YELOW}${set_dashboard_user}${COLOR_END}"
        echo -e ""
        fun_input_dashboard_pwd
        [ -n "${input_dashboard_pwd}" ] && set_dashboard_pwd="${input_dashboard_pwd}"
        echo -e "${program_name} dashboard_pwd: ${COLOR_YELOW}${set_dashboard_pwd}${COLOR_END}"
        echo -e ""
        fun_input_token
        [ -n "${input_token}" ] && set_token="${input_token}"
        echo -e "${program_name} token: ${COLOR_YELOW}${set_token}${COLOR_END}"
        echo -e ""
        fun_input_subdomain_host
        [ -n "${input_subdomain_host}" ] && set_subdomain_host="${input_subdomain_host}"
        echo -e "${program_name} subdomain_host: ${COLOR_YELOW}${set_subdomain_host}${COLOR_END}"
        echo -e ""
        fun_input_max_pool_count
        [ -n "${input_number}" ] && set_max_pool_count="${input_number}"
        echo -e "${program_name} max_pool_count: ${COLOR_YELOW}${set_max_pool_count}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}log_level${COLOR_END}"
        echo    "1: info (default)"
        echo    "2: warn"
        echo    "3: error"
        echo    "4: debug"
        echo    "5: trace"
        echo    "-------------------------"
        read -e -p "Enter your choice (1, 2, 3, 4, 5 or exit. default [1]): " str_log_level
        case "${str_log_level}" in
			1|[Ii][Nn][Ff][Oo])
				str_log_level="info"
				;;
			2|[Ww][Aa][Rr][Nn])
				str_log_level="warn"
				;;
			3|[Ee][Rr][Rr][Oo][Rr])
				str_log_level="error"
				;;
			4|[Dd][Ee][Bb][Uu][Gg])
				str_log_level="debug"
				;;
			5|[Tt][Rr][Aa][Cc][Ee])
				str_log_level="trace"
				;;
			[eE][xX][iI][tT])
				exit 1
				;;
			*)
				str_log_level="info"
				;;
		esac
		echo -e "log_level: ${COLOR_YELOW}${str_log_level}${COLOR_END}"
		echo -e ""
        fun_input_log_max_days
        [ -n "${input_number}" ] && set_log_max_days="${input_number}"
        echo -e "${program_name} log_max_days: ${COLOR_YELOW}${set_log_max_days}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}log_file${COLOR_END}"
        echo    "1: enable (default)"
        echo    "2: disable"
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
        echo -e "log_file: ${COLOR_YELOW}${str_log_file_flag}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}tcp_mux${COLOR_END}"
        echo    "1: enable (default)"
        echo    "2: disable"
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
        echo -e "tcp_mux: ${COLOR_YELOW}${set_tcp_mux}${COLOR_END}"
        echo -e ""
        echo -e "Please select ${COLOR_GREEN}transport protocol support${COLOR_END}"
        echo    "1: enable (default)"
        echo    "2: disable"
        echo "-------------------------"  
        read -e -p "Enter your choice (1, 2 or exit. default [1]): " str_transport_protocol
        case "${str_transport_protocol}" in
            1|[yY]|[yY][eE][sS]|[oO][nN]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
                set_transport_protocol="enable"
				fun_input_kcp_bind_port
        [ -n "${input_port}" ] && set_kcp_bind_port="${input_kcp_bind_port}"
        echo -e "${program_name} kcp_bind_port: ${COLOR_YELOW}${set_kcp_bind_port}${COLOR_END}"
        echo -e ""
			    fun_input_quic_bind_port
        [ -n "${input_port}" ] && set_quic_bind_port="${input_quic_bind_port}"
        echo -e "${program_name} quic_bind_port: ${COLOR_YELOW}${set_quic_bind_port}${COLOR_END}"
        echo -e ""
                ;;
            0|2|[nN]|[nN][oO]|[oO][fF][fF]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
                set_transport_protocol="disable"
				set_kcp_bind_port=0
                set_quic_bind_port=0
                ;;
            [eE][xX][iI][tT])
                exit 1
                ;;
            *)
                set_transport_protocol="enable"
				fun_input_kcp_bind_port
        [ -n "${input_port}" ] && set_kcp_bind_port="${input_kcp_bind_port}"
        echo -e "${program_name} kcp_bind_port: ${COLOR_YELOW}${set_kcp_bind_port}${COLOR_END}"
        echo -e ""
			    fun_input_quic_bind_port
        [ -n "${input_port}" ] && set_quic_bind_port="${input_quic_bind_port}"
        echo -e "${program_name} quic_bind_port: ${COLOR_YELOW}${set_quic_bind_port}${COLOR_END}"
        echo -e ""
                ;;
        esac
        echo -e "transport protocol support: ${COLOR_YELOW}${set_transport_protocol}${COLOR_END}"
        echo -e ""

        echo "============== Check your input =============="
        echo -e "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
        echo -e "Bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
        echo -e "vhost http port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
        echo -e "vhost https port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
        echo -e "Dashboard port     : ${COLOR_GREEN}${set_dashboard_port}${COLOR_END}"
        echo -e "Dashboard user     : ${COLOR_GREEN}${set_dashboard_user}${COLOR_END}"
        echo -e "Dashboard password : ${COLOR_GREEN}${set_dashboard_pwd}${COLOR_END}"
        echo -e "token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
        echo -e "subdomain_host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}"
        echo -e "tcp mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}"
        echo -e "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
        echo -e "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
        echo -e "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
        echo -e "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
        echo -e "transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
        echo -e "kcp bind port      : ${COLOR_GREEN}${set_kcp_bind_port}${COLOR_END}"
        echo -e "quic bind port     : ${COLOR_GREEN}${set_quic_bind_port}${COLOR_END}"
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
    
# Write the configuration to the frps config file

cat << EOF > "${str_program_dir}/${program_config_file}"

bindAddr = "0.0.0.0"
bindPort = ${set_bind_port}

# udp port used for kcp protocol, it can be same with 'bindPort'.
# if not set, kcp is disabled in frps.
kcpBindPort = ${set_kcp_bind_port}

# udp port used for quic protocol.
# if not set, quic is disabled in frps.
quicBindPort = ${set_quic_bind_port}

# Specify which address proxy will listen for, default value is same with bindAddr
# proxyBindAddr = "127.0.0.1"

# quic protocol options
# transport.quic.keepalivePeriod = 10
# transport.quic.maxIdleTimeout = 30
# transport.quic.maxIncomingStreams = 100000

# Heartbeat configure, it's not recommended to modify the default value
# The default value of heartbeatTimeout is 90. Set negative value to disable it.
transport.heartbeatTimeout = 90

# Pool count in each proxy will keep no more than maxPoolCount.
transport.maxPoolCount = ${set_max_pool_count}

# If tcp stream multiplexing is used, default is true
transport.tcpMux = ${set_tcp_mux}

# Specify keep alive interval for tcp mux.
# only valid if tcpMux is true.
# transport.tcpMuxKeepaliveInterval = 30

# tcpKeepalive specifies the interval between keep-alive probes for an active network connection between frpc and frps.
# If negative, keep-alive probes are disabled.
# transport.tcpKeepalive = 7200

# transport.tls.force specifies whether to only accept TLS-encrypted connections. By default, the value is false.
# transport.tls.force = false

# transport.tls.certFile = "server.crt"
# transport.tls.keyFile = "server.key"
# transport.tls.trustedCaFile = "ca.crt"

# If you want to support virtual host, you must set the http port for listening (optional)
# Note: http port and https port can be same with bindPort
vhostHTTPPort = ${set_vhost_http_port}
vhostHTTPSPort = ${set_vhost_https_port}

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
webServer.port = ${set_dashboard_port}
webServer.user = "${set_dashboard_user}"
webServer.password = "${set_dashboard_pwd}"
# webServer.tls.certFile = "server.crt"
# webServer.tls.keyFile = "server.key"
# dashboard assets directory(only for debug mode)
# webServer.assetsDir = "./static"

# Enable golang pprof handlers in dashboard listener.
# Dashboard port must be set first
# webServer.pprofEnable = false

# enablePrometheus will export prometheus metrics on webServer in /metrics api.
# enablePrometheus = true

# console or real logFile path like ./frps.log
log.to = "${str_log_file_flag}"
# trace, debug, info, warn, error
log.level = "${str_log_level}"
log.maxDays = ${set_log_max_days}
# disable log colors when log.to is console, default is false
# log.disablePrintColor = false

# DetailedErrorsToClient defines whether to send the specific error (with debug info) to frpc. By default, this value is true.
# detailedErrorsToClient = true

# auth.method specifies what authentication method to use authenticate frpc with frps.
# If "token" is specified - token will be read into login message.
# If "oidc" is specified - OIDC (Open ID Connect) token will be issued using OIDC settings. By default, this value is "token".
auth.method = "token"

# auth.additionalScopes specifies additional scopes to include authentication information.
# Optional values are HeartBeats, NewWorkConns.
# auth.additionalScopes = ["HeartBeats", "NewWorkConns"]

# auth token
auth.token = "${set_token}"

# userConnTimeout specifies the maximum time to wait for a work connection.
# userConnTimeout = 10

# Max ports can be used for each client, default value is 0 means no limit
# maxPortsPerClient = 0

# If subDomainHost is not empty, you can set subdomain when type is http or https in frpc's configure file
# When subdomain is test, the host used by routing is test.frps.com
subDomainHost = "${set_subdomain_host}"

# custom 404 page for HTTP requests
# custom404Page = "/path/to/404.html"

# specify udp packet size, unit is byte. If not set, the default value is 1500.
# This parameter should be same between client and server.
# It affects the udp and sudp proxy.
# udpPacketSize = 1500

# Retention time for NAT hole punching strategy data.
# natholeAnalysisDataReserveHours = 168

# ssh tunnel gateway
# If you want to enable this feature, the bindPort parameter is required, while others are optional.
# By default, this feature is disabled. It will be enabled if bindPort is greater than 0.
# sshTunnelGateway.bindPort = 2200
# sshTunnelGateway.privateKeyFile = "/home/frp-user/.ssh/id_rsa"
# sshTunnelGateway.autoGenPrivateKeyPath = ""
# sshTunnelGateway.authorizedKeysFile = "/home/frp-user/.ssh/authorized_keys"
EOF
    echo " done"

	echo -n "download ${program_name} ..."
	rm -f ${str_program_dir}/${program_name} ${program_init}
	fun_download_file
	echo "Done"
	echo ""
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

	[ -s ${program_init} ] && ln -sf ${program_init} /usr/bin/${program_name}

	# Start the frps service
	${program_init} start

	# Check if the frps service started successfully
	if pgrep -x "${program_name}" >/dev/null; then
		echo "${program_name} service started successfully."
		fun_frps
		echo -e "${COLOR_GREEN}
	┌─────────────────────────────────────────┐
	│   frp service started successfully.     │
	└─────────────────────────────────────────┘
	┌─────────────────────────────────────────┐
	│  Installation completed successfully.   │
	└─────────────────────────────────────────┘${COLOR_END}"
	echo ""
	else
		echo -e "${COLOR_RED}
	┌─────────────────────────────────────────┐
	│   frp service failed to start.          │
	└─────────────────────────────────────────┘	
	┌─────────────────────────────────────────┐
	│ Installation failed, Please re-install. │
	└─────────────────────────────────────────┘${COLOR_END}"
	echo ""
	# Remove the installed service
    if [ "${OS}" == 'CentOS' ]; then
        chkconfig --del ${program_name}
    else
        update-rc.d -f ${program_name} remove
    fi
			exit 1
fi
    # Print the frps configuration
    echo ""
    echo "Congratulations, ${program_name} install completed!"
    echo "================================================"
    echo -e "You Server IP      : ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "bind port          : ${COLOR_GREEN}${set_bind_port}${COLOR_END}"
    echo -e "vhost http port    : ${COLOR_GREEN}${set_vhost_http_port}${COLOR_END}"
    echo -e "vhost https port   : ${COLOR_GREEN}${set_vhost_https_port}${COLOR_END}"
    echo -e "token              : ${COLOR_GREEN}${set_token}${COLOR_END}"
    echo -e "subdomain_host     : ${COLOR_GREEN}${set_subdomain_host}${COLOR_END}"
    echo -e "tcp mux            : ${COLOR_GREEN}${set_tcp_mux}${COLOR_END}"
    echo -e "Max Pool count     : ${COLOR_GREEN}${set_max_pool_count}${COLOR_END}"
    echo -e "Log level          : ${COLOR_GREEN}${str_log_level}${COLOR_END}"
    echo -e "Log max days       : ${COLOR_GREEN}${set_log_max_days}${COLOR_END}"
    echo -e "Log file           : ${COLOR_GREEN}${str_log_file_flag}${COLOR_END}"
    echo -e "transport protocol : ${COLOR_GREEN}${set_transport_protocol}${COLOR_END}"
    echo -e "kcp bind port      : ${COLOR_GREEN}${set_kcp_bind_port}${COLOR_END}"
    echo -e "quic bind port     : ${COLOR_GREEN}${set_quic_bind_port}${COLOR_END}"	
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

            # Stop frps server
            ${program_init} stop

            rm -f ${program_init} /var/run/${program_name}.pid /usr/bin/${program_name}
            rm -fr ${str_program_dir}
            echo "${program_name} uninstall success!"
            ;;
        *)
            echo ""
            str_uninstall="n"
            esac
        if [ "${str_uninstall}" == 'n' ]; then
            echo "You select [No],shell exit!"
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
        search_dashboard_user=`grep "dashboard_user" ${str_program_dir}/${program_config_file}`
        search_dashboard_pwd=`grep "dashboard_pwd" ${str_program_dir}/${program_config_file}`
        search_kcp_bind_port=`grep "kcp_bind_port" ${str_program_dir}/${program_config_file}`
		search_quic_bind_port=`grep "quic_bind_port" ${str_program_dir}/${program_config_file}`
        search_tcp_mux=`grep "tcp_mux" ${str_program_dir}/${program_config_file}`
        search_token=`grep "privilege_token" ${str_program_dir}/${program_config_file}`
        search_allow_ports=`grep "privilege_allow_ports" ${str_program_dir}/${program_config_file}`
        if [ -z "${search_dashboard_user}" ] || [ -z "${search_dashboard_pwd}" ] || [ -z "${search_kcp_bind_port}" ] || [ -z "${search_quic_bind_port}" ] || [ -z "${search_tcp_mux}" ] || [ ! -z "${search_token}" ] || [ ! -z "${search_allow_ports}" ];then
            echo -e "${COLOR_GREEN}Configuration files need to be updated, now setting:${COLOR_END}"
            echo ""
            if [ ! -z "${search_token}" ];then
                sed -i "s/privilege_token/token/" ${str_program_dir}/${program_config_file}
            fi
            if [ -z "${search_dashboard_user}" ] && [ -z "${search_dashboard_pwd}" ];then
                def_dashboard_user_update="admin"
                read -e -p "Please input dashboard_user (Default: ${def_dashboard_user_update}):" set_dashboard_user_update
                [ -z "${set_dashboard_user_update}" ] && set_dashboard_user_update="${def_dashboard_user_update}"
                echo "${program_name} dashboard_user: ${set_dashboard_user_update}"
                echo ""
                def_dashboard_pwd_update=`fun_randstr 8`
                read -e -p "Please input dashboard_pwd (Default: ${def_dashboard_pwd_update}):" set_dashboard_pwd_update
                [ -z "${set_dashboard_pwd_update}" ] && set_dashboard_pwd_update="${def_dashboard_pwd_update}"
                echo "${program_name} dashboard_pwd: ${set_dashboard_pwd_update}"
                echo ""
                sed -i "/dashboard_port =.*/a\dashboard_user = ${set_dashboard_user_update}\ndashboard_pwd = ${set_dashboard_pwd_update}\n" ${str_program_dir}/${program_config_file}
            fi
            if [ -z "${search_kcp_bind_port}" ];then 
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
                    [eE][xX][iI][tT])
                        exit 1
                        ;;
                    *)
                        set_transport_protocol="enable"
                        ;;
                esac
                echo "transport protocol support: ${set_transport_protocol}"
                def_kcp_bind_port=( $( __readINI ${str_program_dir}/${program_config_file} common bind_port ) )
                if [[ "${set_transport_protocol}" == "disable" ]]; then
                    sed -i "/^bind_port =.*/a\# udp port used for transport protocol, it can be same with 'bind_port'\n# if not set, transport protocol is disabled in frps\n#kcp_bind_port = ${def_kcp_bind_port}\n" ${str_program_dir}/${program_config_file}
                else
                    sed -i "/^bind_port =.*/a\# udp port used for transport protocol, it can be same with 'bind_port'\n# if not set, kcp is disabled in frps\nkcp_bind_port = ${def_kcp_bind_port}\n" ${str_program_dir}/${program_config_file}
                fi
            fi
            if [ -z "${search_tcp_mux}" ];then
                echo "# Please select tcp_mux "
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
                echo "tcp_mux: ${set_tcp_mux}"
                sed -i "/^privilege_mode = true/d" ${str_program_dir}/${program_config_file}
                sed -i "/^token =.*/a\# if tcp stream multiplexing is used, default is true\ntcp_mux = ${set_tcp_mux}\n" ${str_program_dir}/${program_config_file}
            fi
            if [ ! -z "${search_allow_ports}" ];then
                sed -i "s/privilege_allow_ports/allow_ports/" ${str_program_dir}/${program_config_file}
            fi
        fi
        verify_dashboard_user=`grep "^dashboard_user" ${str_program_dir}/${program_config_file}`
        verify_dashboard_pwd=`grep "^dashboard_pwd" ${str_program_dir}/${program_config_file}`
        verify_kcp_bind_port=`grep "kcp_bind_port" ${str_program_dir}/${program_config_file}`
		verify_quic_bind_port=`grep "quic_bind_port" ${str_program_dir}/${program_config_file}`
        verify_tcp_mux=`grep "^tcp_mux" ${str_program_dir}/${program_config_file}`
        verify_token=`grep "privilege_token" ${str_program_dir}/${program_config_file}`
        verify_allow_ports=`grep "privilege_allow_ports" ${str_program_dir}/${program_config_file}`
        if [ ! -z "${verify_dashboard_user}" ] && [ ! -z "${verify_dashboard_pwd}" ] && [ ! -z "${verify_kcp_bind_port}" ] && [ ! -z "${verify_tcp_mux}" ] && [ -z "${verify_token}" ] && [ -z "${verify_allow_ports}" ];then
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
        check_os_version
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
check_os_version
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
