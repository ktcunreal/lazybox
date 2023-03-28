#!/bin/bash
# Simple script to add ocserv user

# Check privilege
if [[ ! `whoami` == "root" ]]; then
	echo "SU privilege is required";
	exit 1;
fi

# Username check
if [ -z $1 ]; then
	echo "Empty username is not allowed";
	exit 1;
fi

if [[ -n "`grep -w $1 /etc/ocserv/ocpasswd`" ]]; then
	echo "User seems already exist, please check /etc/ocserv/ocpasswd for detail";
	exit 1;
fi

# Generate random seed
if [ -z "$SALT" ];then 
	export SALT=`cat /dev/urandom | tr -dc '1-9A-Za-z' | fold -w16 | head -n1`
fi

# Generate user-token
TOKEN=`echo "$1,${SALT}" | md5sum | base64`

# Add user to ocpasswd
echo "# $1,${SALT}" >> /etc/ocserv/ocpasswd
echo "${TOKEN}:*:" >> /etc/ocserv/ocpasswd 

# Print token
echo "USERNAME: $1"
echo "TOKEN: ${TOKEN}"