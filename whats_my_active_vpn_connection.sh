active_conn=$(echo `nmcli -f TYPE,DEVICE,NAME c | egrep 'vpn\s+[^- ]+' | awk '{$1=$2=""; print $0}' | xargs`)
if [ ! -z "$active_conn" ];then
	echo "* Detected active VPN connection:"
	echo
	/usr/bin/figlet -f digital $active_conn
	echo
else
	echo "* Currently no active VPN connection"
fi
