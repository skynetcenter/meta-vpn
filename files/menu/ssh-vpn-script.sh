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
	  ssh-vpn-script
	  ;;
	esac
}

function add-user() {
	clear
	echo -e ""
	echo -e "${B}==========================${N}"
	echo -e " • Add SSH OpenVPN User • "
	echo -e "${B}==========================${N}"
	read -p "Username : " user
	if getent passwd $user > /dev/null 2>&1; then
		echo ""
		echo "User $user already exist"
		echo ""
		goback
	fi
	read -p "Password : " pass
	read -p "Duration (Day) : " duration
	useradd -e $(date -d +${duration}days +%Y-%m-%d) -s /bin/false -M $user
	echo -e "$pass\n$pass\n"|passwd $user &> /dev/null
	echo -e "${user}\t${pass}\t$(date -d +${duration}days +%Y-%m-%d)" >> /metavpn/ssh/ssh-clients.txt

	exp=$(date -d +${duration}days +"%d %b %Y")

	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • User Information • "
	echo -e "${B}======================${N}"
	echo -e "Username\t: $user "
	echo -e "Password\t: $pass"
	echo -e "Expired Date\t: $exp"
	echo -e ""
	goback
}

function delete-user() {
	clear
	echo -e ""
	echo -e "${B}=============================${N}"
	echo -e " • Delete SSH OpenVPN User • "
	echo -e "${B}=============================${N}"
	read -p "Username : " user
	if getent passwd $user > /dev/null 2>&1; then
		userdel $user
		sed -i "/\b$user\b/d" /metavpn/ssh/ssh-clients.txt
		echo -e ""
		echo -e "User $user deleted successfully"
		echo -e ""
	else
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
	fi 
	goback
}

function extend-user() {
	clear
	echo -e ""
	echo -e "${B}=============================${N}"
	echo -e " • Extend SSH OpenVPN User • "
	echo -e "${B}=============================${N}"
	read -p "Username : " user
	if ! getent passwd $user > /dev/null 2>&1; then
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
		goback
	fi
	read -p "Duration (Day) : " extend

	exp_old=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
	diff=$((($(date -d "${exp_old}" +%s)-$(date +%s))/(86400)))
	duration=$(expr $diff + $extend + 1)

	chage -E $(date -d +${duration}days +%Y-%m-%d) $user
	exp_new=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
	exp=$(date -d "${exp_new}" +"%d %b %Y")

	clear
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e " • User Information • "
	echo -e "${B}======================${N}"
	echo -e "Username\t: $user "
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
	n=0
	while read expired; do
		account=$(echo $expired | cut -d: -f1)
		id=$(echo $expired | grep -v nobody | cut -d: -f3)
		exp=$(chage -l $account | grep "Account expires" | awk -F": " '{print $2}')
		if [[ $id -ge 1000 ]] && [[ $exp != "never" ]]; then
			exp_date=$(date -d "${exp}" +"%d %b %Y")
			printf "%-17s %2s\n" "$account" "$exp_date"
			n=$((n+1))
		fi
	done < /etc/passwd
	echo -e "------------------------------"
	echo -e "Total Accounts : $n"
	echo -e ""
	goback
}

function user-monitor() {
	data=($(ps aux | grep -i dropbear | awk '{print $2}'))
	clear
	echo -e ""
	echo -e "${B}==============================${N}"
	echo -e "  • Dropbear Login Monitor •  "
	echo -e "${B}==============================${N}"
	n=0
	for pid in "${data[@]}"; do
		num=$(cat /var/log/auth.log | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$pid\]" | wc -l)
		user=$(cat /var/log/auth.log | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$pid\]" | awk '{print $10}' | tr -d "'")
		ip=$(cat /var/log/auth.log | grep -i dropbear | grep -i "Password auth succeeded" | grep "dropbear\[$pid\]" | awk '{print $12}')
		if [ $num -eq 1 ]; then
			echo -e "$pid - $user - $ip"
			n=$((n+1))
		fi
	done
	echo -e "------------------------------"
	echo -e "Total Logins: $n"
	echo -e ""
	echo -e "${B}=================================${N}"
	echo -e " • OpenVPN (TCP) Login Monitor • "
	echo -e "${B}=================================${N}"
	a=$(grep -n "Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since" /var/log/openvpn/server-tcp-status.log | awk -F":" '{print $1}')
	b=$(expr $(grep -n "ROUTING TABLE" /var/log/openvpn/server-tcp-status.log | awk -F":" '{print $1}') - 1)
	c=$(expr ${b} - ${a})
	cat /var/log/openvpn/server-tcp-status.log | head -n $b | tail -n $c | sed -e 's/,/\t/g' > /tmp/openvpn-tcp-login.txt
	n=0
	while read login; do
		user=$(echo $login | awk '{print $1}')
		ip=$(echo $login | awk '{print $2}')
		echo -e "$user - $ip"
		n=$((n+1))
	done < /tmp/openvpn-tcp-login.txt
	echo -e "---------------------------------"
	echo -e "Total Logins: $n"
	echo -e ""
	echo -e "${B}=================================${N}"
	echo -e " • OpenVPN (UDP) Login Monitor • "
	echo -e "${B}=================================${N}"
	a=$(grep -n "Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since" /var/log/openvpn/server-udp-status.log | awk -F":" '{print $1}')
	b=$(expr $(grep -n "ROUTING TABLE" /var/log/openvpn/server-udp-status.log | awk -F":" '{print $1}') - 1)
	c=$(expr ${b} - ${a})
	cat /var/log/openvpn/server-udp-status.log | head -n $b | tail -n $c | sed -e 's/,/\t/g' > /tmp/openvpn-udp-login.txt
	n=0
	while read login; do
		user=$(echo $login | awk '{print $1}')
		ip=$(echo $login | awk '{print $2}')
		echo -e "$user - $ip"
		n=$((n+1))
	done < /tmp/openvpn-udp-login.txt
	echo -e "---------------------------------"
	echo -e "Total Logins: $n"
	echo -e ""
	goback
}

function show-information() {
	clear
	echo -e ""
	echo -e "${B}=======================${N}"
	echo -e "  • SSH Information •  "
	echo -e "${B}=======================${N}"
	read -p "Username\t: " user
	if getent passwd $user > /dev/null 2>&1; then
		pass=$(cat /metavpn/ssh/ssh-clients.txt | grep -w "$user" | awk '{print $2}')
		exp=$(cat /metavpn/ssh/ssh-clients.txt | grep -w "$user" | awk '{print $3}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		ip=$(wget -qO- ipv4.icanhazip.com)
		echo -e "Password\t: $pass"
		echo -e "Expired\t: $exp_date"
		echo -e ""
		echo -e "${B}========================${N}"
		echo -e "  • Host Information •  "
		echo -e "${B}========================${N}"
		echo -e "Host\t\t: $ip"
		echo -e "Dropbear\t: 85"
		echo -e "Stunnel\t\t: 465"
		echo -e "Squid Proxy\t: 8080"
		echo -e "OHP Dropbear\t: 3128"
		echo -e "OHP OpenVPN\t: 8000"
		echo -e "UDPGW\t\t: 7300"
		echo -e ""
	else
		echo -e ""
		echo -e "User $user does not exist"
		echo -e ""
	fi 
	goback
}

function ovpn-config() {
	clear 
	ip=$(wget -qO- ipv4.icanhazip.com)
	echo -e ""
	echo -e "${B}======================${N}"
	echo -e "  • OpenVPN Config •  "
	echo -e "${B}======================${N}"
	echo -e " [1] Config TCP"
	echo -e " [2] Config UDP"
	echo -e ""
	echo -e " [0] Exit"
	echo -e ""
	until [[ ${option} =~ ^[1-2]$ ]] || [[ ${option} == '0' ]]; do
		read -rp "Select option : " option
	done
	case "${option}" in
	1)
		clear 
		echo -e ""
		echo -e "${B}==========================${N}"
		echo -e " • OpenVPN Config - TCP • "
		echo -e "${B}==========================${N}"
		echo -e ""
		bug="$1"
		read -p "Enter bug host : " bug 
		if [[ $bug != "$1" ]]; then 
		cp /metavpn/openvpn/client-tcp.ovpn /metavpn/openvpn/${bug}.ovpn 
		sed -i "s+remote $ip 1194+remote $ip:1194@$bug/+g" /metavpn/openvpn/${bug}.ovpn
		sed -i "s/;http-proxy $ip 8080/http-proxy $ip 8080/g" /metavpn/openvpn/${bug}.ovpn
		sed -i "s/;http-proxy-retry/http-proxy-retry/g" /metavpn/openvpn/${bug}.ovpn
		cat /metavpn/openvpn/${bug}.ovpn 
		rm -r /metavpn/openvpn/${bug}.ovpn
		else
		cat /metavpn/openvpn/client-tcp.ovpn
		fi 
		echo -e ""
		goback
		;;
	2)
		clear
		echo -e "${B}==========================${N}"
		echo -e " • OpenVPN Config - UDP • "
		echo -e "${B}==========================${N}"
		echo -e ""
		cat /metavpn/openvpn/client-udp.ovpn
		echo -e ""
		goback
		;;
	0)
		ssh-vpn-script
		;;
	esac
}

clear
echo -e ""
echo -e "${B}========================${N}"
echo -e "  • SSH OpenVPN Menu •  "
echo -e "${B}========================${N}"
echo -e ""
echo -e " [1] Add User"
echo -e " [2] Delete User"
echo -e " [3] Extend User"
echo -e " [4] User List"
echo -e " [5] User Monitor"
echo -e " [6] SSH Information"
echo -e " [7] OVPN Config"
echo -e ""
echo -e " [0] Back"
echo -e ""
until [[ ${option} -ge 1 ]] && [[ ${option} -le 7 ]] || [[ ${option} == '0' ]]; do
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
		show-information
		;;
	7)
		ovpn-config
		;;
	0)
		menu
		;;
esac
