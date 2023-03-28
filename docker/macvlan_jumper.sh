#########################################
#### Dummy ip for macvlan container             ####
#### Author: ktcunreal@gmail.com                  ####
#### 2020                                                                      ####
#########################################

ip link add dummy link enp5s0 type macvlan mode bridge
ip addr add 192.168.0.255/32 dev dummy
ip link set dummy up
ip route add 192.168.0.25/32 dev dummy