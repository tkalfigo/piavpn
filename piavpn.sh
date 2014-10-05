#!/bin/bash

# set -x

check_sudo() {
	if [ `/usr/bin/whoami` != 'root' ];then
		echo 'ERROR: run script with sudo'
		exit -1;
	fi
}
	
get_active_conn() {
	echo `nm-tool | grep VPN | awk -F'-' '{print$3}' | sed "s/\(.*\).\{2\}/\1/"`
}

has_active_conn() {
	active_conn=$(get_active_conn)
	if [ ! -z $active_conn ];then
		return 1
	fi
	return 0
}

print_help() {
	/bin/cat << EOF

* Usage: sudo $0 <option>

  where <option> is only one of:

	-l|--list	lists the PIA regions activated for nmcli. 
			For details on doing this, read:
			https://askubuntu.com/questions/57339/connect-disconnect-from-vpn-from-the-command-line/57409#57409?newreg=21c40769970a48909e8fee3df7bb308f
	-g|--geolocation	prints where PIA thinks your IP is located
	-s|--state	prints your current PIA vpn endpoint
	-u|--up <region name>	Start vpn connection to <region name>. Valid <region name>'s are those returned using "$0 -l" and should be typed between quotes e.g. sudo $0 -u "PIA - Sweden"
	-k|--kill	terminates the currently active vpn connection if one is active
	-h|--help	this message
EOF
}

# Remove temporary files
clean_up() {
	if [ -f "$lynx_temp_file" ];then
		/bin/rm $lynx_temp_file
	fi
	if [ -f "$nmcli_regions_file" ];then
		/bin/rm $nmcli_regions_file
	fi
	echo -e "* Exiting\n"
}
print_where_is_my_ip() {
	echo "* PIA says you are at:"
	lynx_temp_file=`mktemp`
	/usr/bin/lynx -dump https://www.privateinternetaccess.com/pages/whats-my-ip/ | egrep 'City|Region|Country' > $lynx_temp_file &
	# PID of running job is stored as $!
	print_busy_spinner $!
	# show user's location according to PIA
	/bin/cat $lynx_temp_file
	rm $lynx_temp_file
}

# Saves nmcli enabled regions in temp file $nmcli_regions_file
save_nmcli_enabled_regions() {
	nmcli_regions_file=`mktemp`
	reg_count=0
	find /etc/NetworkManager/system-connections/PIA* | while read f;do 
		# Assuming that a file that has a 'password-flags=1' and a '[vpn-secrets]' section, is enabled for nmcli
		# -a ! -z $(sudo grep 'password-flags=0' "$f"
		if [ ! -z $(sudo grep 'vpn-secrets' "$f") ];then 
			echo "$f" | awk -F'system-connections/' '{print$2}' >> $nmcli_regions_file
			reg_count=$((reg_count+1))
		fi
	done
}

print_nmcli_activated_regions() {
	save_nmcli_enabled_regions
	echo "* nmcli enabled PIA regions: "
	/bin/cat $nmcli_regions_file
}

check_region_is_valid() {
	if [ ! -z "`grep "$1" $nmcli_regions_file`" ];then
		return 0;
	fi
	return -1;
}

# PID of the running command passed as 1st arg
print_busy_spinner() {
	pid=$1
	spin='-\|/'
	i=0
	while kill -0 $pid 2>/dev/null;do
		i=$(( (i+1) %4 ))
		printf "\r* Processing ${spin:$i:1}"
		sleep .1
	done
	# erase the busy spinner line
	echo -n -e "\r                 \r"
}

get_main_choice() {
	active_conn=$(get_active_conn)
	echo
	echo -e "\t1. Terminate active VPN connection "
	echo -e "\t2. Start new VPN connection"
	echo -e "\t3. Exit"
	echo
	echo -n "Your choice: "
	read val
	if [ "$val" -ge 1 -a "$val" -le 3 ];then
		return "$val";
	fi
	return -1;
}

get_region_choice() {
	echo
	echo -e "\t1. Switzerland"
	echo -e "\t2. Sweden"
	echo -e "\t3. Romania"
	echo -e "\t4. US East"
	echo -e "\t5. US West"
	echo -e "\t6. CA Toronto"
	echo -e "\t7. Netherlands"
	echo
	echo -n "Pick a region: "
	read val
	if [ "$val" -ge 1 -a "$val" -le 7 ];then
		return "$val";
	fi
	return -1;
}

start_new_conn() {
	case "$1" in
		1|"PIA - Switzerland")
			/usr/bin/nmcli connection up id "PIA - Switzerland" &
		;;
		2|'PIA - Sweden')
			/usr/bin/nmcli connection up id "PIA - Sweden" &
		;;
		3|'PIA - Romania')
			/usr/bin/nmcli connection up id "PIA - Romania" &
		;;
		4|'PIA - US East')
			/usr/bin/nmcli connection up id "PIA - US East" &
		;;
		5|'PIA - US West')
			/usr/bin/nmcli connection up id "PIA - US West" &
		;;
		6|'PIA - CA Toronto')
			/usr/bin/nmcli connection up id "PIA - CA Toronto" &
		;;
		7|'PIA - Netherlands')
			/usr/bin/nmcli connection up id "PIA - Netherlands" &
		;;
		*)
			echo "ERROR: Invalid region choice"
			return -1
		;;
	esac
	# Pass PID of running nmcli job as 1st param
	print_busy_spinner $!
	# return the exit code of executing nmcli
	return $?
}

print_region() {
	active_conn=$(get_active_conn)
	if [ ! -z "$active_conn" ];then
		echo -n "* Detected active VPN connection: "
		if hash figlet 2>/dev/null;then
			echo -e "\n"
			/usr/bin/figlet -f digital $active_conn
		else
			echo -e "$active_conn\n"
		fi
		echo
	else
		echo "* Current no active VPN connection"
	fi
}

stop_active_conn() {
	active_conn=$(get_active_conn)
	if [ -z "$active_conn" ];then
		echo "ERROR: no active VPN connection"
		return -1
	else
		active_conn="PIA - $active_conn"
		echo "* Terminating VPN connection: $active_conn"
		/usr/bin/nmcli con down id "$active_conn" &
		# PID of running job is stored as $!
		print_busy_spinner $!
		if [ $? -ne 0 ];then
			echo "ERROR: Failed to stop VPN connection"
			return -2
		else
			echo "* Terminated successfully"
			return 0
		fi
	fi
}

main_loop() {
	while true;do
		get_main_choice
		main_choice=$?
		if [ "$main_choice" -lt 0 ];then
			echo "ERROR: Invalid choice"
			continue
		else
			if [ "$main_choice" -eq 1 ];then
				stop_active_conn
				continue
			elif [ "$main_choice" -eq 2 ];then
				active_conn=$(get_active_conn)
				if [ ! -z "$active_conn" ];then
					stop_active_conn
					if [ $? -ne 0 ];then
						continue
					fi
				fi
				get_region_choice
				region_choice=$?
				start_new_conn "$region_choice"
				if [ $? -ne 0 ];then
					continue
				else 
					echo "* VPN connection successful"
				fi
			else
				echo 
				exit 0;
			fi
			break;
		fi
	done
	print_where_is_my_ip
	exit 0
}


### MAIN ###

trap clean_up EXIT

if [ $# -gt 0 ];then
	while [[ $# > 0 ]];do
		key="$1"
		shift

		case $key in
			-l|--list)
				check_sudo
				echo "* List of PIA regions activated for nmcli:"
				print_nmcli_activated_regions
		    		exit 0
		    	;;
			-g|--geolocation)
				print_where_is_my_ip
				exit 0
			;;
			-s|--status)
				print_region
				shift
			;;
			-u|--up)
				check_sudo
				region_name=$1
				shift
				save_nmcli_enabled_regions
				check_region_is_valid "$region_name"
				if [ $? -ne 0 ];then
					echo "ERROR: region '$region_name' is invalid"
					exit -1
				fi
				has_active_conn 
				if [ $? -eq 1 ]; then
					stop_active_conn
				fi
				echo "* Starting VPN connection to: $region_name"
				start_new_conn "$region_name"
				if [ $? -eq 0 ];then
					echo "* Connection established."
					print_where_is_my_ip
					exit 0
				fi
			;;
			-k|--kill)
				check_sudo
				stop_active_conn
				exit 0
			;;
			-h|--help)
				print_help
				exit 0
			;;
			*)
				echo "* Invalid option: $key"
				print_help
				exit 0
			;;
		esac
	done
else
	check_sudo
	print_where_is_my_ip
	print_region	
	main_loop
fi
