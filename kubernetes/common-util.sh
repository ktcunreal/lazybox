#!/usr/bin/env bash

K8S_MASTER_ADDR=
K8S_DNS_ADDR=

function add-route() {
ip route add 10.96.0.0/12 via ${K8S_MASTER_ADDR}
ip route add 10.244.0.0/16 via ${K8S_MASTER_ADDR}
print_success "Routing rules updated"
ip route
}

function update-resolvconf(){
cat << EOF > /etc/resolv.conf
nameserver ${K8S_DNS_ADDR}
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
EOF
print_success "Resolvconf updated"
cat /etc/resolv.conf
}

function clean-images(){
docker images | awk '{print $3}' | tail -n+2 | xargs docker rmi
print_success "Cleaned unused images"
}

function help(){
    printf "Usage:\n\t$0 add-route\n\t$0 update-resolvconf\n\t$0 clean-images\n"
}

function chk_privilege(){
   if [[ ! `whoami` == "root" ]]; then
	print_err "Su privilege is required";
	exit 1;
   fi
}

function print_fmt() {
    echo "[`date +%Y-%m-%d' '%H:%M:%S`] $1";
}

function print_success() {
    echo -n "[`date +%Y-%m-%d' '%H:%M:%S`] `tput setaf 2; echo $1; tput setaf 9;`"; 
}

function print_hl() {
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
	chk_privilege;
	$1;
fi