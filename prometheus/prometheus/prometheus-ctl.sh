#!/usr/bin/env bash

LOG_FILE=/home/ubuntu/prometheus-suite/prometheus/prometheus.log
MAX_TSDB_SIZE="8192MB"

function start() {
	print_format "Checking process pid"
	if [ -e /tmp/prometheus/pid ];then 
		print_err "Pid exists, prometheus is already running"
		exit 1;
	fi;
	
	print_format "Creating tmp directory"
	mkdir -p /tmp/prometheus || true

	print_format "Starting prometheus..."
	nohup ./prometheus --storage.tsdb.retention.size=${MAX_TSDB_SIZE} --web.enable-admin-api > prometheus.log 2>&1 &

	echo $! > /tmp/prometheus/pid
	print_green "Prometheus is running"
}

function stop() {
	print_format "Checking process pid"
	if [ ! -e /tmp/prometheus/pid ];then
		print_err "Pid not found, prometheus is not running"
		exit 1;
	fi

	print_format "SIGTERM sent"
	kill `cat /tmp/prometheus/pid`

	print_format "Waiting for gracefully shutdown..."
	sleep 5;

	
	if [ ! -z "$(ps -ef | grep [`cut -c1 /tmp/prometheus/pid`]`cut -c2- /tmp/prometheus/pid`)" ];then
		print_err "Process took more than 5s to shutdown, force killing..."
		kill -9 `cat /tmp/prometheus/pid`
	fi
	
	print_green "Promethus has stopped"
	print_format "Removing pid file"
	rm /tmp/prometheus/pid -f
}

function reload(){
	print_format "Checking process pid"
        if [ ! -e /tmp/prometheus/pid ];then
                print_err "Pid not found, prometheus is not running"
                exit 1;
        fi

	print_format "(If you had invalid configurations, this operation would not have any effect"
	print_format "Check prometheus log for detail)"

        kill -1 `cat /tmp/prometheus/pid`
        print_format "SIGHUP sent"

        print_green "Config reload complete."

}

function status(){
	if [ -e /tmp/prometheus/pid ];then 
		print_green "Promethus is running"
	else
		print_err "Prometheus is not running"
        fi

}

function restart(){
	if [ -e /tmp/prometheus/pid ];then 
		print_format "Stopping prometheus process..."
		stop;
	fi

	start;
}

function log(){
	tail -fn400 $LOG_FILE
}

function help(){
	echo -e "prometheus-ctl usage:\n<start>\n<stop>\n<reload>\n<restart>\n<status>"
}

function print_format() {
    echo "[`date +%Y-%m-%d' '%H:%M:%S`] $1";
}

function print_green() {
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 2; echo $1; tput setaf 9;`"; 
}

function print_highlight() {
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 3; echo $1; tput setaf 9;`"; 
}

function print_err(){
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 1; echo $1; tput setaf 9;`"; 
}

if [ -z "$1" ]; then 
	print_err "Invalid operation!"
	help;
	exit 1;
else
	$1;
fi