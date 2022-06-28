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
	  xray-script
	  ;;
	esac
}

function add-user() {
	clear
	echo -e ""
	echo -e "${B}=====================${N}"
	echo -e "  • Add Xray User •  "
	echo -e "${B}=====================${N}"
	read -p "Username : " user
	if grep -qw "$user" /metavpn/xray/xray-clients.txt; then
		echo -e ""
		echo -e "User $user already exist"
		echo -e ""
		goback
	fi
	read -p "Duration (Day) : " duration

	uuid=$(uuidgen)
	while grep -qw "$uuid" /metavpn/xray/xray-clients.txt; do
		uuid=$(uuidgen)
	done
	exp=$(date -d +${duration}days +%Y-%m-%d)
	expired=$(date -d "${exp}" +"%d %b %Y")
	domain=$(cat /usr/local/etc/xray/domain)
	email=${user}@${domain}
	echo -e "${user}\t${uuid}\t${exp}" >> /metavpn/xray/xray-clients.txt

	cat /usr/local/etc/xray/xtls.json | jq '.inbounds[0].settings.clients += [{"id": "'${uuid}'","flow": "xtls-rprx-direct","email": "'${email}'"}]' > /usr/local/etc/xray/xtls_tmp.json
	mv -f /usr/local/etc/xray/xtls_tmp.json /usr/local/etc/xray/xtls.json
	cat /usr/local/etc/xray/ws.json | jq '.inbounds[0].settings.clients += [{"id": "'${uuid}'","email": "'${email}'"}]' > /usr/local/etc/xray/ws_tmp.json
	mv -f /usr/local/etc/xray/ws_tmp.json /usr/local/etc/xray/ws.json
	systemctl daemon-reload
	systemctl restart xray@xtls
	systemctl restart xray@ws

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

function delete-user() {
	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • Delete Xray User • "
	echo -e "${B}======================${N}"
	read -p "Username : " user
	if ! grep -qw "$user" /metavpn/xray/xray-clients.txt; then
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
	uuid="$(cat /metavpn/xray/xray-clients.txt | grep -w "$user" | awk '{print $2}')"

	cat /usr/local/etc/xray/xtls.json | jq 'del(.inbounds[0].settings.clients[] | select(.id == "'${uuid}'"))' > /usr/local/etc/xray/xtls_tmp.json
	mv -f /usr/local/etc/xray/xtls_tmp.json /usr/local/etc/xray/xtls.json
	cat /usr/local/etc/xray/ws.json | jq 'del(.inbounds[0].settings.clients[] | select(.id == "'${uuid}'"))' > /usr/local/etc/xray/ws_tmp.json
	mv -f /usr/local/etc/xray/ws_tmp.json /usr/local/etc/xray/ws.json
	sed -i "/\b$user\b/d" /metavpn/xray/xray-clients.txt
	systemctl daemon-reload
	systemctl restart xray@xtls
	systemctl restart xray@ws
	echo -e ""
	echo -e "User $user deleted successfully"
	echo -e ""
	goback
}

function extend-user() {
	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • Extend Xray User • "
	echo -e "${B}======================${N}"
	read -p "Username : " user
	if ! grep -qw "$user" /metavpn/xray/xray-clients.txt; then
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
	read -p "Duration (Day) : " extend

	uuid=$(cat /metavpn/xray/xray-clients.txt | grep -w $user | awk '{print $2}')
	exp_old=$(cat /metavpn/xray/xray-clients.txt | grep -w $user | awk '{print $3}')
	diff=$((($(date -d "${exp_old}" +%s)-$(date +%s))/(86400)))
	duration=$(expr $diff + $extend + 1)
	exp_new=$(date -d +${duration}days +%Y-%m-%d)
	exp=$(date -d "${exp_new}" +"%d %b %Y")

	sed -i "/\b$user\b/d" /metavpn/xray/xray-clients.txt
	echo -e "$user\t$uuid\t$exp_new" >> /metavpn/xray/xray-clients.txt

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
	while read expired; do
		user=$(echo $expired | awk '{print $1}')
		exp=$(echo $expired | awk '{print $3}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		printf "%-17s %2s\n" "$user" "$exp_date"
	done < /metavpn/xray/xray-clients.txt
	total=$(wc -l /metavpn/xray/xray-clients.txt | awk '{print $1}')
	echo -e "------------------------------"
	echo -e "Total Accounts: $total"
	echo -e ""
	goback
}

function user-monitor() {
	data=($(cat /metavpn/xray/xray-clients.txt | awk '{print $1}'))
	data2=($(netstat -anp | grep ESTABLISHED | grep tcp6 | grep xray | grep -w 443 | awk '{print $5}' | cut -d: -f1 | sort | uniq))
	domain=$(cat /usr/local/etc/xray/domain)
	clear
	echo -e ""
	echo -e "${B}=============================${N}"
	echo -e " • Xray-XTLS Login Monitor • "
	echo -e "${B}=============================${N}"
	n=0
	for user in "${data[@]}"; do
		touch /tmp/ipxray.txt
		for ip in "${data2[@]}"; do
			total=$(cat /var/log/xray/access-xtls.log | grep -w ${user}@${domain} | awk '{print $3}' | cut -d: -f1 | grep -w $ip | sort | uniq)
			if [[ "$total" == "$ip" ]]; then
				echo -e "$total" >> /tmp/ipxray.txt
				n=$((n+1))
			fi
		done
		total=$(cat /tmp/ipxray.txt)
		if [[ -n "$total" ]]; then
			total2=$(cat /tmp/ipxray.txt | nl)
			echo -e "$user :"
			echo -e "$total2"
		fi
		rm -f /tmp/ipxray.txt
	done
	echo -e "-----------------------------"
	echo -e "Total Logins: $n"
	echo -e ""
	echo -e "${B}=============================${N}"
	echo -e "  • Xray-WS Login Monitor •  "
	echo -e "${B}=============================${N}"
	n=0
	data3=($(netstat -anp | grep ESTABLISHED | grep tcp | grep nginx | grep -w 80 | awk '{print $5}' | cut -d: -f1 | sort | uniq))
	for user in "${data[@]}"; do
		touch /tmp/ipxray.txt
		for ip in "${data3[@]}"; do
			total=$(cat /var/log/xray/access-ws.log | grep -w ${user}@${domain} | awk '{print $3}' | cut -d: -f1 | grep -w $ip | sort | uniq)
			if [[ "$total" == "$ip" ]]; then
				echo -e "$total" >> /tmp/ipxray.txt
				n=$((n+1))
			fi
		done
		total=$(cat /tmp/ipxray.txt)
		if [[ -n "$total" ]]; then
			total2=$(cat /tmp/ipxray.txt | nl)
			echo -e "$user :"
			echo -e "$total2"
		fi
		rm -f /tmp/ipxray.txt
	done
	echo -e "-----------------------------"
	echo -e "Total Logins: $n"
	echo -e ""
	goback
}

function show-config() {
	clear
	echo -e ""
	echo -e "${B}=====================${N}"
	echo -e "   • Xray Config •   "
	echo -e "${B}=====================${N}"
	read -p "Username\t: " user
	if ! grep -qw "$user" /metavpn/xray/xray-clients.txt; then
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
	uuid=$(cat /metavpn/xray/xray-clients.txt | grep -w "$user" | awk '{print $2}')
	domain=$(cat /usr/local/etc/xray/domain)
	exp=$(cat /metavpn/xray/xray-clients.txt | grep -w "$user" | awk '{print $3}')
	exp_date=$(date -d"${exp}" "+%d %b %Y")

	echo -e "Expired Date\t: $exp_date"
	echo -e ""
	bug="$1"
	read -p "Enter bug SNI : " bug 
	if [[ $bug != "$1" ]]; then 
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e "   • VLESS + XTLS •   "
	echo -e "${B}======================${N}"
	echo -e "Adress\t\t: $domain"
	echo -e "Port\t\t: 443"
	echo -e "ID\t\t: $uuid"
	echo -e "Flow\t\t: xtls-rprx-direct"
	echo -e "Encryption\t: none"
	echo -e "Network\t\t: tcp"
	echo -e "Header Type\t: none"
	echo -e "TLS\t\t: xtls"
	echo -e ""
	echo -e "Link : vless://$uuid@$domain:443?security=xtls&encryption=none&flow=xtls-rprx-direct&sni=${bug}#XRAY_XTLS-$user"
	echo -e ""
	echo -e "${B}====================${N}"
	echo -e "  • Scan QR Code •  "
	echo -e "${B}====================${N}"
	qrencode -t ansiutf8 -l L "vless://$uuid@$domain:443?security=xtls&encryption=none&flow=xtls-rprx-direct&sni=${bug}#XRAY_XTLS-$user"
	echo -e ""
	echo -e "${B}=======================${N}"
	echo -e " • VLESS + Websocket • "
	echo -e "${B}=======================${N}"
	echo -e "Adress\t\t: $domain"
	echo -e "Port\t\t: 80"
	echo -e "ID\t\t: $uuid"
	echo -e "Encryption\t: none"
	echo -e "Network\t\t: ws"
	echo -e "Path\t\t: /xray"
	echo -e ""
	echo -e "Link : vless://$uuid@$domain:80?path=%2Fxray&security=none&encryption=none&host=$domain&type=ws#XRAY_WS-$user"
	echo -e ""
	echo -e "${B}====================${N}"
	echo -e "  • Scan QR Code •  "
	echo -e "${B}====================${N}"
	qrencode -t ansiutf8 -l L "vless://$uuid@$domain:80?path=%2Fxray&security=none&encryption=none&host=$domain&type=ws#XRAY_WS-$user"
	echo -e ""
	else 
	bug="$domain"
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e "   • VLESS + XTLS •   "
	echo -e "${B}======================${N}"
	echo -e "Adress\t\t: $domain"
	echo -e "Port\t\t: 443"
	echo -e "ID\t\t: $uuid"
	echo -e "Flow\t\t: xtls-rprx-direct"
	echo -e "Encryption\t: none"
	echo -e "Network\t\t: tcp"
	echo -e "Header Type\t: none"
	echo -e "TLS\t\t: xtls"
	echo -e ""
	echo -e "Link : vless://$uuid@$domain:443?security=xtls&encryption=none&flow=xtls-rprx-direct&sni=${bug}#XRAY_XTLS-$user"
	echo -e ""
	echo -e "${B}====================${N}"
	echo -e "  • Scan QR Code •  "
	echo -e "${B}====================${N}"
	qrencode -t ansiutf8 -l L "vless://$uuid@$domain:443?security=xtls&encryption=none&flow=xtls-rprx-direct&sni=${bug}#XRAY_XTLS-$user"
	echo -e ""
	echo -e "${B}=======================${N}"
	echo -e " • VLESS + Websocket • "
	echo -e "${B}=======================${N}"
	echo -e "Adress\t\t: $domain"
	echo -e "Port\t\t: 80"
	echo -e "ID\t\t: $uuid"
	echo -e "Encryption\t: none"
	echo -e "Network\t\t: ws"
	echo -e "Path\t\t: /xray"
	echo -e ""
	echo -e "Link : vless://$uuid@$domain:80?path=%2Fxray&security=none&encryption=none&host=$domain&type=ws#XRAY_WS-$user"
	echo -e ""
	echo -e "${B}====================${N}"
	echo -e "  • Scan QR Code •  "
	echo -e "${B}====================${N}"
	qrencode -t ansiutf8 -l L "vless://$uuid@$domain:80?path=%2Fxray&security=none&encryption=none&host=$domain&type=ws#XRAY_WS-$user"
	echo -e ""
	fi 
	goback
}

clear
echo -e ""
echo -e "${B}=======================${N}"
echo -e "  • Xray Vless Menu •  "
echo -e "${B}=======================${N}"
echo -e ""
echo -e " [1] Add User"
echo -e " [2] Delete User"
echo -e " [3] Extend User"
echo -e " [4] User List"
echo -e " [5] User Monitor"
echo -e " [6] Xray Config"
echo -e ""
echo -e " [0] Back"
echo -e ""
until [[ ${option} -ge 1 ]] && [[ ${option} -le 6 ]] || [[ ${option} == '0' ]]; do
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
	user-monitor
	;;
6)
	show-config
	;;
0)
	menu
	;;
esac
