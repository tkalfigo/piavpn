activeVPN=`nm-tool |grep VPN | awk -F'-' '{print$3}'| sed "s/\(.*\).\{2\}/\1/"`

if [ -z "$activeVPN" ];then
	echo "ERROR: no active VPN connection; exiting..."
else
	activeVPN="PIA -$activeVPN"
	echo "Stopping VPN connection: $activeVPN"
	sudo /usr/bin/nmcli con down id "$activeVPN"
	if [ $? -eq 0 ];then
		echo "Stopped successfully"
	else
		echo "ERROR: failed to stop VPN connection: $activeVPN"
	fi
fi
