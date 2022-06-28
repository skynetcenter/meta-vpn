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

check_run() {
	if [[ "$(systemctl is-active $1)" == "active" ]]; then
		echo -e "${G}Running${N}"
	else
		echo -e "${R}Not Running${N}"
	fi
}

check_screen() {
	if screen -ls | grep -qw $1; then
		echo -e "${G}Running${N}"
	else
		echo -e "${R}Not Running${N}"
	fi
}

goback() {
	echo -e "Press enter to go back \c"
	read back 
	case $back in 
	*)
	  menu 
	  ;;
	esac
}

clear
echo -e ""
echo -e "${B}=============================${N}"
echo -e "     • Services Status •     "
echo -e "${B}=============================${N}"
echo -e ""
echo -e " SSH\t\t: $(check_run ssh)"
echo -e " Dropbear\t: $(check_run dropbear)"
echo -e " Stunnel\t: $(check_run stunnel4)"
echo -e " OpenVPN (UDP)\t: $(check_run openvpn@server-udp)"
echo -e " OpenVPN (TCP)\t: $(check_run openvpn@server-tcp)"
echo -e " Squid Proxy\t: $(check_run squid)"
echo -e " OHP Dropbear\t: $(check_screen ohp-dropbear)"
echo -e " OHP OpenVPN\t: $(check_screen ohp-openvpn)"
echo -e " BadVPN UDPGW\t: $(check_screen badvpn)"
echo -e " Nginx\t\t: $(check_run nginx)"
echo -e " Xray XTLS\t: $(check_run xray@xtls)"
echo -e " Xray WS\t: $(check_run xray@ws)"
echo -e " WireGuard\t: $(check_run wg-quick@wg0)"
echo -e " Fail2Ban\t: $(check_run fail2ban)"
echo -e " DDOS Deflate\t: $(check_run ddos)"
echo -e ""
echo -e "${B}=============================${N}"
echo -e ""
goback
