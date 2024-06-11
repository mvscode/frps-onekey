#!/bin/bash

# Startup script for frp service
# Place in /etc/init.d and run 'update-rc.d -f frps defaults'
# For service run: 'chkconfig --add frps'

#=========================================================
#   System Required:  CentOS/Debian/Ubuntu/Fedora (32bit/64bit)
#   Description:  Manager for frps, Written by Clang
#   Maintainer：MvsCode
#=========================================================

### BEGIN INIT INFO
# Provides:          frps
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the frps
# Description:       starts frps using start-stop
### END INIT INFO

# Paths and variables
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
PROGRAM_NAME="Frps"
PROGRAM_PATH="/usr/local/frps"
SERVICE_NAME="frps"
BIN="${PROGRAM_PATH}/${SERVICE_NAME}"
CONFIGFILE="${PROGRAM_PATH}/frps.toml"
SCRIPT_NAME="/etc/init.d/${SERVICE_NAME}"
VERSION="2023"
PROGRAM_VERSION=$("$BIN" --version)
RET_VAL=0

# Check if the binary exists
[ -x "$BIN" ] || exit 0

# Print the header
print_header() {
    echo "+---------------------------------------------------------+"
    echo "|     Manager for ${PROGRAM_NAME}, Author Clang, Maintainer MvsCode      |"
    echo "+---------------------------------------------------------+"
}

# Check if the service is running
check_run() {
    local PID=$(pgrep -f "$BIN")
    [ -n "$PID" ]
}

# Load the configuration file
load_config() {
    [ -r "$CONFIGFILE" ] || { echo "config file $CONFIGFILE not found"; return 1; }
}

start() {
    print_header
    if check_run; then
        echo "${PROGRAM_NAME} (pid $PID) already running."
        return 0
    fi
    load_config || return 1
    echo -n "Starting ${PROGRAM_NAME} (${PROGRAM_VERSION})..."
    "$BIN" -c "$CONFIGFILE" >/dev/null 2>&1 &
    sleep 1
    if ! check_run; then
        echo "start failed"
        return 1
    fi
    echo " done"
    echo "${PROGRAM_NAME} (pid $PID) is running."
}

stop() {
    print_header
    if ! check_run; then
        echo "${PROGRAM_NAME} is not running."
        return 0
    fi
    echo -n "Stopping ${PROGRAM_NAME} (pid $PID)... "
    kill $PID
    [ $? -eq 0 ] && echo " done" || echo " failed"
}

restart() {
    stop
    start
}

status() {
    check_run && echo "${PROGRAM_NAME} (pid $PID) is running..." || echo "${PROGRAM_NAME} is stopped"
}

config() {
    [ -s "$CONFIGFILE" ] && vi "$CONFIGFILE" || echo "${PROGRAM_NAME} configuration file not found!"
}

version() {
    echo "${PROGRAM_NAME} version ${PROGRAM_VERSION}"
}

help() {
    "$BIN" --help
}

case "${1:-}" in
    start|stop|restart|status|config)
        "$1"
        ;;
    version|VERSION|-v|--version)
        version
        ;;
    config|CONFIG|conf|CONF|-c|--config)
        config
        ;;
    help|HELP|-h|--help)
        help
        ;;
    *)
        print_header
        echo "Usage: $SCRIPT_NAME {start|stop|restart|status|config|version|help}"
        RET_VAL=1
        ;;
esac
exit $RET_VAL
