active_conn=$(echo `nm-tool | grep VPN | awk -F'-' '{print$3}' | sed "s/\(.*\).\{2\}/\1/"`)
if [ ! -z "$active_conn" ];then
	echo "* Detected active VPN connection:"
	echo
	/usr/bin/figlet -f digital $active_conn
	echo
else
	echo "* Current no active VPN connection"
fi
