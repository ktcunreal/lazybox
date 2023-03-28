#!/bin/bash

VOLUMEPATH=/mnt/Shared_Volume

while getopts "i:h:a:p:n:" arg; do
	case $arg in
		i)
			IP=$OPTARG
			echo "Assigned IP: $OPTARG" ;;
		n)
			HOSTNAME=$OPTARG
			echo "Assigned HOSTNAME: $OPTARG" ;;
		a)
			ALIAS=$OPTARG
			echo "Assigned ALIAS: $OPTARG" ;;
		p)
		    PRESET=$OPTARG
		    echo "Selected Preset: $OPTARG" ;;
		h)
			echo -n "Usage:" ;;
		?)
	    	echo "unknown argument $arg=$OPTARG" exit 1 ;;
	esac
done
	
read -p "Confirm? (y/N)" CHOICE
if [ "$CHOICE" = "y" ];then
#	tar -xJvf $VOLUMEPATH/Preset/$PRESET.tar.xz && mv $VOLUMEPATH/$PRESET $VOLUMEPATH/$HOSTNAME;
    tar -xJvf $VOLUMEPATH/Preset/$PRESET.tar.xz -C $VOLUMEPATH && mv $VOLUMEPATH/$PRESET $VOLUMEPATH/$HOSTNAME
	DIR=$VOLUMEPATH/$HOSTNAME;
	docker create -h $HOSTNAME \
			  --ip $IP \
			  --name $HOSTNAME \
			  --network macvlan \
			  --privileged \
              --restart=always \
			  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
			  -v $DIR/etc:/etc/ \
			  -v $DIR/var:/var \
			  -v $DIR/usr:/usr \
			  -v $DIR/data:/data \
			  -v $DIR/root:/root \
			    centos:7 \
			  /usr/sbin/init
	docker start $HOSTNAME;
	if [ "$ALIAS" != "" ];then
		echo \
		"alias $ALIAS='sshpass -p centos ssh -o "StrictHostKeyChecking=no" root@$IP'" \
		>> /mnt/Shared_Volume/JUMPER/etc/jumprc;
		echo "Done!";
	fi
fi
