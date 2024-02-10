#!/bin/bash

function get_ip_from_interface() {
    IP=$(ip -o -4 addr show dev $1 | head -n 1 | awk '{print $4}' | cut -d '/' -f 1 )
    echo $IP
}

# Function to perform ping for each address
function perform_ping() {
    echo "Performing pings on ${ADDRESSES[*]} using interface $1"

    successful_pings=0

    for addr in "${ADDRESSES[@]}"; do
        ping -c $PING_REQUESTS $addr -I $1 -W $INTERVAL_BTW_PING >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            successful_pings=$((successful_pings + 1))
        fi
    done

    if [ $successful_pings -ge $MIN_PINGS ]; then
        echo "Pings successfully performed for $successful_pings addresses."
        return 0
    else
        echo "Error: Unable to perform the minimum number of successful pings."
        return 1
    fi
}

function load_config() {
    # Read the configurations from the provided file
    config_file="$1"

    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        exit 1
    fi

    # Load the configurations from the file
    source "$config_file"

    # Check if all the required configurations have been defined
    if [ -z "$INTERFACE" ] || [ -z "$INTERVAL" ] || [ -z "$ETH_METRIC" ] || [ -z "$MODEM_METRIC" ] || [ -z "$PING_REQUESTS" ] || [ -z "$INTERVAL_BTW_PING" ] || [ -z "$MIN_PINGS" ] || [ -z "$ADDRESS" ]; then
        echo "Error: The configuration file is incomplete."
        exit 1
    fi

    # Convert the comma-separated addresses string into an array
    IFS=',' read -r -a ADDRESSES <<< "$ADDRESS"
}

function get_max_default_route(){
    route=$(route | grep default | head -n 1 | awk '{print $8}')
    echo $route
}

function restart_modem(){
    echo -e "AT+CFUN=1,1\r" > /dev/ttyUSB3
    sleep 120
}

function wait_for_eth_ip(){
    timeout=30
    wait_time=0
    interval=5  # Interval in seconds to check for the interface

    while [ $wait_time -lt $timeout ]; do
        if ip link show eth0.2 &>/dev/null; then
            ETH_IP=$(get_ip_from_interface $INTERFACE)
            if [ "$ETH_IP" != "" ]; then
                return 0
            fi
        else
            echo -e "Waiting for interface eth0.2 to be available..."
        fi
        sleep $interval
        wait_time=$((wait_time + interval))
    done

    if [ $wait_time -eq $timeout ]; then
        echo -e "Timeout waiting for eth0.2 ip"
        return 1
    fi
}

function check_for_non_metric_interface() {
    local non_metric_route=$(ip route show default | grep 'default via' | grep -v 'metric' | head -n 1)
    if [ -n "$non_metric_route" ]; then
        ip route del $non_metric_route 
        echo -e "Deleted non-metric route"
    fi
}

# Check if the configuration file has been provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <configuration_file>"
    exit 1
fi


load_config $1
while true; do
    check_for_non_metric_interface
    echo "Connectivity check date: $(date)"
    echo "Checking wired internet connection"
    wait_for_eth_ip
    if [ $? -eq 0 ]; then
        # Connectivity check
        perform_ping $INTERFACE
        if [ $? -eq 0 ]; then
            echo -e "  OK."
             # Verify routes and prioritize Ethernet as the default
            route=$(get_max_default_route)
            if [ "$route" != "$INTERFACE" ]; then
                echo -e " Updating router table to use $INTERFACE as default"
                ip route add default via $ETH_IP dev $INTERFACE metric $ETH_METRIC
            fi
            sleep "$INTERVAL"
            continue
        else
            echo -e "  Error: Unable to perform the minimum number of successful pings."
            echo -e "  Resetting wired internet connection"
            ip link set dev $INTERFACE down
            sleep 5
            ip link set dev $INTERFACE up
        fi
    else
        echo -e " Wired internet not found"
    fi

    # Without wired network, check the modem
    echo "Checking modem status"
    if [[ -e /dev/cdc-wdm0 ]]; then # QMI interface available
        if ! ip link show wwan0 &>/dev/null; then
            echo -e " Error: Modem interface not found. Trying to bring it up."
            if ! ip link set dev wwan0 up &>/dev/null; then
                echo -e "  Failed to bring up the modem interface. Restarting the modem."
                restart_modem
                continue
            fi
            echo -e " OK."
        fi
        MODEM_IP=$(get_ip_from_interface wwan0)
        if [ "$MODEM_IP" == "" ]; then
            echo -e " Obtaining an IP for the modem interface"
            qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online'
            qmicli -d /dev/cdc-wdm0 -w
            ip link set dev wwan0 down
            echo Y > /sys/class/net/wwan0/qmi/raw_ip
            ip link set dev wwan0 up
            qmi-network /dev/cdc-wdm0 start
            udhcpc -q -f -n -i wwan0 &>/dev/null
        
            MODEM_IP=$(get_ip_from_interface wwan0)
            if [ "$MODEM_IP" == "" ]; then
                echo -e "  Error: Failed to obtain an IP for the modem interface"
                restart_modem
                continue
            fi
            echo "  OK."
        fi
        # Modem interface with an IP, check routes
        route=$(get_max_default_route)
        if [ "$route" != "wwan0" ]; then
            echo -e " Updating router table to use wwan0 as default"
            ip route add default via $MODEM_IP dev wwan0 metric 20
        fi
        echo " OK."
	perform_ping wwan0
	if [ $? -eq 0 ]; then
            echo -e "  OK."
            sleep "$INTERVAL"
            continue
        else
            echo -e "  Error: Unable to perform the minimum number of successful pings."
            echo -e "  Resetting wireless internet connection"
	    restart_modem
	fi

    else
        echo -e " Error: QMI interface not found."
    fi
    sleep "$INTERVAL"
done