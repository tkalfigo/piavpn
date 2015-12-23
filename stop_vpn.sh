activeVPN=`nmcli -f TYPE,DEVICE,NAME c | egrep 'vpn\s+[^- ]+' | awk '{$1=$2=""; print $0}' | xargs`

if [ -z "$activeVPN" ];then
	echo "ERROR: no active VPN connection; exiting..."
else
	echo "Stopping VPN connection: $activeVPN"
	sudo /usr/bin/nmcli con down id "$activeVPN"
	if [ $? -eq 0 ];then
		echo "Stopped successfully"
	else
		echo "ERROR: failed to stop VPN connection: $activeVPN"
	fi
fi
