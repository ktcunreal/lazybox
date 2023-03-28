#!/bin/bash
# Simple script to delete ocserv user

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

_FILTERED_NAME=`echo $1 | tr -dc '[:alnum:]-+'`

if [[ -z "`grep -w ${_FILTERED_NAME} /etc/ocserv/ocpasswd`" ]]; then
	echo "User not exist";
	exit 1;
fi


# Delete User
sed -i "/^# ${_FILTERED_NAME}/,+1 d" /etc/ocserv/ocpasswd
echo "User $1 deleted"
