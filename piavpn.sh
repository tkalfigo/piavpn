#!/bin/bash

# set -x

check_sudo() {
	if [ `/usr/bin/whoami` != 'root' ];then
		echo 'Error: run script with sudo'
		exit 1;
	fi
}
	
get_active_conn() {
	echo `nm-tool | grep VPN | awk -F'[' '{print$2}' | awk -F']' '{print$1}'`
}

pretty_print() {
	if hash figlet 2>/dev/null;then
		echo -e "\n"
		/usr/bin/figlet -f digital $1
	else
		echo -e "$1\n"
	fi
}

has_active_conn() {
	active_conn=$(get_active_conn)
	if [ ! -z "$active_conn" ];then
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
	# echo -e "* Exiting\n"
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

print_where_is_my_ip() {
	/bin/ping -c 3 google.com 2>&1 1>/dev/null &
	# Cannot use print_busy_spinner here because we need the exit code of the job; so we wait()
	wait $!
	if [ $? -ne 0 ];then
		pretty_print "No network!"
		return 1
	else
		echo "* PIA says you are at:"
		lynx_temp_file=`mktemp`
		/usr/bin/lynx -dump https://www.privateinternetaccess.com/pages/whats-my-ip/ | egrep 'my IP Address[^?]|City|Region|Country' > $lynx_temp_file &
		# PID of running job is stored as $!
		print_busy_spinner $!
		# show user's location according to PIA
		/bin/cat $lynx_temp_file
		rm $lynx_temp_file
		return 0
	fi
}

# Saves nmcli enabled regions in temp file $nmcli_regions_file
save_nmcli_enabled_regions() {
	nmcli_regions_file=`mktemp`
	find /etc/NetworkManager/system-connections/PIA* | while read f;do 
		# Assuming that a file that has a 'password-flags=1' and a '[vpn-secrets]' section, is enabled for nmcli
		# -a ! -z $(sudo grep 'password-flags=0' "$f"
		if [ ! -z $(sudo grep 'vpn-secrets' "$f") ];then 
			echo "$f" | awk -F'system-connections/' '{print$2}' >> $nmcli_regions_file
		fi
	done
}

print_nmcli_enabled_regions() {
	save_nmcli_enabled_regions
	echo "* nmcli enabled PIA regions: "
	/bin/cat $nmcli_regions_file
}

check_region_is_valid() {
	if [ ! -z "`grep "$1" $nmcli_regions_file`" ];then
		return 0
	fi
	return 1;
}

print_main_choices() {
	# array element at [0] is not used
	valid_choices=(invalid 1 2 3 4 5)
	active_conn=$(get_active_conn)
	echo
	echo -e "\t1. Show active VPN connection"
	echo -e "\t2. Where is my external IP located? (according to PIA)"
	echo -e "\t3. Terminate active VPN connection "
	echo -e "\t4. Start new VPN connection"
	echo -e "\t5. Exit"
	echo
	echo -n "Your choice: "
	read val
	while true;do
		if [ "${valid_choices[$val]}" != "invalid" ];then
			return $val
		else
			echo "Error: Invalid choice"
			echo -n "Your choice: "
			read val
		fi
	done
	return "$val"
}

# Prints regions list and generates the $regions_arr at the same time from the $nmcli_regions_file 
print_region_choices() {
	echo
	reg_count=1 # generated regions_arr is 1-indexed and not 0-indexed for convenience
	while read next_region;do
		regions_arr[$reg_count]=$next_region
		echo -e "\t${reg_count}. $next_region"
		reg_count=$((reg_count+1))
	done < $nmcli_regions_file
	echo
	echo -n "Pick a region: "
	read selected_region_index
	if [ "$selected_region_index" -lt 1 -o "$selected_region_index" -ge $reg_count ];then
		echo "Error: invalid region"
		exit 3
	fi
}

start_IPv6_leak_protection() {
	echo "* IPv6 leak protection for interface '$active_interface': ON";
	echo 1 > /proc/sys/net/ipv6/conf/$active_interface/disable_ipv6
}

stop_IPv6_leak_protection() {
	echo "* IPv6 leak protection for interface '$active_interface': OFF";
	echo 0 > /proc/sys/net/ipv6/conf/$active_interface/disable_ipv6
}

# First arg is the region's full name or the region's index (from the listling of nmcli enabled regions)
start_new_conn() {
	start_IPv6_leak_protection
	case "$1" in
		1|"PIA - CA North York")
			/usr/bin/nmcli connection up id "PIA - CA North York" &
		;;
		2|'PIA - CA Toronto')
			/usr/bin/nmcli connection up id "PIA - CA Toronto" &
		;;
		3|'PIA - France')
			/usr/bin/nmcli connection up id "PIA - France" &
		;;
		4|'PIA - Germany')
			/usr/bin/nmcli connection up id "PIA - Germany" &
		;;
		5|'PIA - Hong Kong')
			/usr/bin/nmcli connection up id "PIA - Hond Kong" &
		;;
		6|'PIA - Netherlands')
			/usr/bin/nmcli connection up id "PIA - Netherlands" &
		;;
		7|'PIA - Romania')
			/usr/bin/nmcli connection up id "PIA - Romania" &
		;;
		8|'PIA - Sweden')
			/usr/bin/nmcli connection up id "PIA - Sweden" &
		;;
		9|'PIA - Switzerland')
			/usr/bin/nmcli connection up id "PIA - Switzerland" &
		;;
		10|'PIA - UK London')
			/usr/bin/nmcli connection up id "PIA - UK London" &
		;;
		11|'PIA - UK Southampton')
			/usr/bin/nmcli connection up id "PIA - UK Southampton" &
		;;
		12|'PIA - US California')
			/usr/bin/nmcli connection up id "PIA - US California" &
		;;
		13|'PIA - US East')
			/usr/bin/nmcli connection up id "PIA - US East" &
		;;
		14|'PIA - US Florida')
			/usr/bin/nmcli connection up id "PIA - US Florida" &
		;;
		15|'PIA - US Midwest')
			/usr/bin/nmcli connection up id "PIA - US Midwest" &
		;;
		16|'PIA - US Seattle')
			/usr/bin/nmcli connection up id "PIA - US Seattle" &
		;;
		17|'PIA - US Texas')
			/usr/bin/nmcli connection up id "PIA - US Texas" &
		;;
		18|'PIA - US West')
			/usr/bin/nmcli connection up id "PIA - US West" &
		;;
		*)
			stop_IPv6_leak_protection
			echo "Error: Invalid region choice"
			return 1
		;;
	esac
	# Cannot use print_busy_spinner here because we need the exit code of the job; so we wait()
	wait $!
	nmcli_exit_code=$?

	if [ $nmcli_exit_code -ne 0 ];then
		echo -n "Error: failed to start connection; exit code ($nmcli_exit_code) means: "
		print_nmcli_exit_code_msg $nmcli_exit_code
		return $nmcli_exit_code
	else
		return 0
	fi
}

print_nmcli_exit_code_msg() {
	case $1 in
		1)
			echo "'Unknown or unspecified error'"
		;;
		2)
			echo "'Invalid user input, wrong nmcli invocation'"
		;;
		3)
			echo "'Timeout expired (see commands with --timeout option)'"
		;;
		4)
			echo "'Connection activation failed'"
		;;
		5)
			echo "'Connection deactivation failed'"
		;;
		6)
			echo "'Disconnecting device failed'"
		;;
		7)
			echo "'Connection deletion failed'"
		;;
		8)
			echo "'NetworkManager is not running'"
		;;
		9)
			echo "'nmcli and NetworkManager versions mismatch'"
		;;
	esac
}

# Prints active VPN connection's region
print_active_conn_region() {
	active_conn=$(get_active_conn)
	if [ ! -z "$active_conn" ];then
		echo -n "* Detected active VPN connection: "
		pretty_print "$active_conn"
	else
		echo "* Currently no active VPN connection"
	fi
}

stop_active_conn() {
	active_conn=$(get_active_conn)
	if [ -z "$active_conn" ];then
		echo "Error: no active VPN connection"
		return 1
	else
		echo "* Terminating VPN connection: $active_conn"
		/usr/bin/nmcli con down id "$active_conn" &
		# Cannot use print_busy_spinner here because we need the exit code of the job; so we wait()
		wait $!
		nmcli_exit_code=$?
		if [ $nmcli_exit_code -ne 0 ];then
			echo -n "Error: failed to stop VPN connection; exit code ($nmcli_exit_code) means: "
			print_nmcli_exit_code_msg $nmcli_exit_code
			return 2
		else
			stop_IPv6_leak_protection
			return 0
		fi
	fi
}

main_loop() {
	save_nmcli_enabled_regions
	while true;do
		print_main_choices
		main_choice=$? # has already been checked to be a valid choice
		if [ "$main_choice" -eq 1 ];then
			print_active_conn_region
			continue
		elif [ "$main_choice" -eq 2 ];then
			print_where_is_my_ip
			continue
		elif [ "$main_choice" -eq 3 ];then
			stop_active_conn
			if [ $? -eq 0 ];then
				echo "* Terminated successfully"
			fi
			continue
		elif [ "$main_choice" -eq 4 ];then
			print_region_choices # if it doesn't exit, then it has set var selected_region_index
			active_conn=$(get_active_conn)
			if [ ! -z "$active_conn" ];then
				stop_active_conn
				if [ $? -eq 0 ];then
					echo "* Terminated successfully"
				fi
				continue
			fi
			start_new_conn "${regions_arr[$selected_region_index]}"
			if [ $? -eq 0 ];then
				echo "* Connection established"
			fi
			continue
		else
			echo 
			exit 0;
		fi
		break;
	done
	print_where_is_my_ip
	exit 0
}


### MAIN ###

trap clean_up EXIT

active_interface=`/sbin/route | grep default | awk  '{print$8}'`

if [ $# -gt 0 ];then
	while [[ $# > 0 ]];do
		key="$1"
		shift

		case $key in
			-l|--list)
				check_sudo
				echo "* List of PIA regions activated for nmcli:"
				print_nmcli_enabled_regions
		    		exit 0
		    	;;
			-g|--geolocation)
				print_where_is_my_ip
				exit $?
			;;
			-s|--status)
				echo $(get_active_conn)
				shift
			;;
			-u|--up)
				check_sudo
				region_name=$1
				shift
				save_nmcli_enabled_regions
				check_region_is_valid "$region_name"
				if [ $? -ne 0 ];then
					echo "Error: region '$region_name' is invalid"
					exit 1
				fi
				has_active_conn 
				if [ $? -eq 1 ]; then
					stop_active_conn
					if [ $? -eq 0 ];then
						echo "* Terminated successfully"
					fi
				fi
				echo "* Starting VPN connection to: $region_name"
				start_new_conn "$region_name"
				if [ $? -eq 0 ];then
					echo "* Connection successful"
					exit 0
				fi
			;;
			-k|--kill)
				check_sudo
				stop_active_conn
				if [ $? -eq 0 ];then
					echo "* Terminated successfully"
				fi
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
	print_active_conn_region	
	main_loop
fi
