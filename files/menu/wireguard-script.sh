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

goback() {
	echo -e "Press enter to go back \c"
	read back 
	case $back in 
	*)
	  wireguard-script
	  ;;
	esac
}

source /etc/wireguard/params

function add-user() {
	endpoint="${ip}:51820"

	clear
	echo -e ""
	echo -e "${B}========================${N}"
	echo -e " • Add WireGuard User • "
	echo -e "${B}========================${N}"
	read -p "Username : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		echo -e ""
		echo -e "User $user already exist"
		echo -e ""
		exit 0
	fi
	read -p "Duration (Day) : " duration
	exp=$(date -d +${duration}days +%Y-%m-%d)
	expired=$(date -d "${exp}" +"%d %b %Y")

	for dot_ip in {2..254}; do
		dot_exists=$(grep -c "10.66.66.${dot_ip}" /etc/wireguard/wg0.conf)
		if [[ ${dot_exists} == '0' ]]; then
			break
		fi
	done
	if [[ ${dot_exists} == '1' ]]; then
		echo -e ""
		echo -e "${ERROR} The subnet configured only supports 253 clients${N}"
		echo -e ""
		goback
	fi

	client_ipv4="10.66.66.${dot_ip}"
	client_priv_key=$(wg genkey)
	client_pub_key=$(echo "${client_priv_key}" | wg pubkey)
	client_pre_shared_key=$(wg genpsk)

	echo -e "$user\t$exp" >> /metavpn/wireguard/wireguard-clients.txt
	echo -e "[Interface]
PrivateKey = ${client_priv_key}
Address = ${client_ipv4}/32
DNS = 8.8.8.8,8.8.4.4

[Peer]
PublicKey = ${server_pub_key}
PresharedKey = ${client_pre_shared_key}
Endpoint = ${endpoint}
AllowedIPs = 0.0.0.0/0" >> /metavpn/wireguard/${user}.conf
	echo -e "\n### Client ${user}
[Peer]
PublicKey = ${client_pub_key}
PresharedKey = ${client_pre_shared_key}
AllowedIPs = ${client_ipv4}/32" >> /etc/wireguard/wg0.conf
	systemctl daemon-reload
	systemctl restart wg-quick@wg0

	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • User Information • "
	echo -e "${B}======================${N}"
	echo -e "Username\t: $user"
	echo -e "Expired Date\t: $expired"
	echo -e ""
	goback
}

function delete-user(){
	clear
	echo -e ""
	echo -e "${B}===========================${N}"
	echo -e " • Delete WireGuard User • "
	echo -e "${B}===========================${N}"
	read -p "Username : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		sed -i "/^### Client ${user}\$/,/^$/d" /etc/wireguard/wg0.conf
		if grep -q "### Client" /etc/wireguard/wg0.conf; then
			line=$(grep -n AllowedIPs /etc/wireguard/wg0.conf | tail -1 | awk -F: '{print $1}')
			head -${line} /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		else
			head -6 /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		fi
		rm -f /metavpn/wireguard/${user}.conf
		sed -i "/\b$user\b/d" /metavpn/wireguard/wireguard-clients.txt
		systemctl daemon-reload
		systemctl restart wg-quick@wg0
		echo -e ""
		echo -e "User $user deleted successfully"
		echo -e ""
		goback
	else
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi 
}

function extend-user() {
	clear
	echo -e ""
	echo -e "${B}===========================${N}"
	echo -e " • Extend WireGuard User • "
	echo -e "${B}===========================${N}"
	read -p "Username : " user
	if ! grep -qw "$user" /metavpn/wireguard/wireguard-clients.txt; then
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
	read -p "Duration (Day) : " extend

	exp_old=$(cat /metavpn/wireguard/wireguard-clients.txt | grep -w $user | awk '{print $2}')
	diff=$((($(date -d "${exp_old}" +%s)-$(date +%s))/(86400)))
	duration=$(expr $diff + $extend + 1)
	exp_new=$(date -d +${duration}days +%Y-%m-%d)
	exp=$(date -d "${exp_new}" +"%d %b %Y")

	sed -i "/\b$user\b/d" /metavpn/wireguard/wireguard-clients.txt
	echo -e "$user\t$exp_new" >> /metavpn/wireguard/wireguard-clients.txt

	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • User Information • "
	echo -e "${B}======================${N}"
	echo -e "Username\t: $user"
	echo -e "Expired Date\t: $exp"
	echo -e ""
	goback
}

function user-list() {
	clear
	echo -e ""
	echo -e "${B}==============================${N}"
	echo -e "Username          Expired Date"
	echo -e "${B}==============================${N}"
	while read expired
	do
		user=$(echo $expired | awk '{print $1}')
		exp=$(echo $expired | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		printf "%-17s %2s\n" "$user" "$exp_date"
	done < /metavpn/wireguard/wireguard-clients.txt
	total=$(wc -l /metavpn/wireguard/wireguard-clients.txt | awk '{print $1}')
	echo -e "------------------------------"
	echo -e "Total Accounts: $total"
	echo -e ""
	goback
}

function show-config() {
	clear
	echo -e ""
	echo -e "${B}========================${N}"
	echo -e "  • WireGuard Config •  "
	echo -e "${B}========================${N}"
	read -p "Username : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		exp=$(cat /metavpn/wireguard/wireguard-clients.txt | grep -w "$user" | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		echo -e "Expired : $exp_date"
		echo -e ""
		echo -e "${B}====================${N}"
		echo -e "  • Scan QR Code •  "
		echo -e "${B}====================${N}"
		echo -e ""
		qrencode -t ansiutf8 -l L < /metavpn/wireguard/${user}.conf
		echo -e ""
		echo -e "${B}=====================${N}"
		echo -e "  • Client Config •  "
		echo -e "${B}=====================${N}"
		echo -e ""
		cat /metavpn/wireguard/${user}.conf
		echo -e ""
		goback
	else
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
}

clear
echo -e ""
echo -e "${B}======================${N}"
echo -e "  • WireGuard Menu •  "
echo -e "${B}======================${N}"
echo -e ""
echo -e " [1] Add User"
echo -e " [2] Delete User"
echo -e " [3] Extend User"
echo -e " [4] User List"
echo -e " [5] WireGuard Config"
echo -e ""
echo -e " [0] Back"
echo -e ""
until [[ ${option} -ge 1 ]] && [[ ${option} -le 5 ]] || [[ ${option} == '0' ]]; do
	read -rp "Select option : " option
done
case "${option}" in
1)
	add-user
	;;
2)
	delete-user
	;;
3)
	extend-user
	;;
4)
	user-list
	;;
5)
	show-config
	;;
0)
	menu
	;;
esac
