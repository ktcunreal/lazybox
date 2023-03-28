#!/bin/bash

echo -e "\033[36m						[  本地主机列表  ] \033[0m "
echo -e "\033[33m< SHORTCUT >					< Addr >					< Usage > \033[0m"
#cat ~/hosts.d/sshpass |grep ssh |awk '{print $2 $8 $10}'|awk -F '[=@'\'']' '{print "ALIAS > "$1"					"$4"					"$5}'
echo -e "\033[34m`cat ~/hosts.d/sshpass |grep ssh |awk '{print $2 $8 $10}'|awk -F '[=@'\'']' '{print "Host > "$1"					"$4"					"$5}'`\033[0m"
echo -e "\n\033[36m						[  远程主机列表  ] \033[0m "
echo -e "\033[33m< SHORTCUT >					< Addr >					< Usage > \033[0m"
#cat ~/hosts.d/sshkey |grep ssh | awk -F '[ =@'\''#]' '{print "ALIAS > "$2"					"$6"					"$10}'
echo -e "\033[34m`cat ~/hosts.d/sshkey |grep ssh | awk -F '[ =@'\''#]' '{print "Host > "$2"					"$6"					"$10}'`\033[0m"
