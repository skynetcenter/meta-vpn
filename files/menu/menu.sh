#!/bin/bash

# Color
N="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;34m"
Y="\033[0;33m"
C="\033[0;36m"
P="\033[0;35m"
LR="\033[1;31m"
LG="\033[1;32m"
LB="\033[1;34m"
RB="\033[41;37m"
GB="\033[42;37m"
BB="\033[44;37m"

# Notification
OK="[ ${LG}OK${N} ]"
ERROR="[ ${LR}ERROR${N} ]"
INFO="[ ${C}INFO${N} ]"

# Source
repo="https://raw.githubusercontent.com/aspbersatu/multivpn-ubuntu/main/"

goback() {
	echo -e "Press enter to go back \c"
	read back 
	case $back in 
	*)
	  menu 
	  ;;
	esac
}

update_script() {
	clear
	echo -e ""
	echo -e "${INFO} ${B}Updating script ...${N}"
	sleep 1
	rm -f /usr/bin/{menu,ssh-vpn-script,xray-script,wireguard-script,check-script}
	rm -f /metavpn/cron.daily
	wget -O /usr/bin/menu "${repo}files/menu/menu.sh" > /dev/null 2>&1
	wget -O /usr/bin/ssh-vpn-script "${repo}files/menu/ssh-vpn-script.sh" > /dev/null 2>&1
	wget -O /usr/bin/xray-script "${repo}files/menu/xray-script.sh" > /dev/null 2>&1
	wget -O /usr/bin/wireguard-script "${repo}files/menu/wireguard-script.sh" > /dev/null 2>&1
	wget -O /usr/bin/check-script "${repo}files/menu/check-script.sh" > /dev/null 2>&1
	wget -O /usr/bin/nench-script "${repo}files/menu/nench-script.sh" > /dev/null 2>&1
	wget -O /usr/bin/stream-script "${repo}files/menu/stream-script.sh" > /dev/null 2>&1
	wget -O /metavpn/cron.daily "${repo}files/cron.daily" > /dev/null 2>&1
	chmod +x /usr/bin/{menu,ssh-vpn-script,xray-script,wireguard-script,check-script,nench-script,stream-script}
	chmod +x /metavpn/cron.daily
	echo -e "${OK} Script updated successfully${N}"
	echo -e ""
	goback
}

clear
echo -e ""
echo -e "${B}===========================${N}"
echo -e "     • Meta VPN Menu •     "
echo -e "${B}===========================${N}"
echo -e ""
echo -e " [1] SSH OpenVPN Menu"
echo -e " [2] Xray Vless Menu"
echo -e " [3] WireGuard Menu"
echo -e " [4] Server Speedtest"
echo -e " [5] Server Benchmark"
echo -e " [6] Service Status"
echo -e " [7] Streaming Service"
echo -e " [8] Update Script"
echo -e ""
echo -e " [0] Exit"
echo -e ""
echo -e "${B}===========================${N}"
echo -e ""
until [[ ${option} -ge 1 ]] && [[ ${option} -le 8 ]] || [[ ${option} == '0' ]]; do
	read -rp "Select option : " option
done
case "${option}" in
	1)
		ssh-vpn-script
		;;
	2)
		xray-script
		;;
	3)
		wireguard-script
		;;
	4)
		clear
		speedtest
		echo -e ""
		goback
		;;
	5)
		nench-script 
		;;
	6)
		check-script
		;;
	7)
		stream-script
		;;
	8)
		update_script
		;;
	0)
		clear
		exit 0
		;;
esac
