systemctl stop kubelet
systemctl stop docker
iptables --flush
iptables -tnat --flush
systemctl start docker
systemctl start kubelet