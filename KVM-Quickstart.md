# KVM-Quickstart
> Host linux-dist: CentOS 7

## Create bridge network config
  
    cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-br0
    DEVICE=br0
    TYPE=Bridge
    BOOTPROTO=static
    IPADDR=192.168.1.10
    NETMASK=255.255.255.0
    GATEWAY=192.168.1.1
    ONBOOT=yes
    EOF

    cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-$ifname
    BRIDGE=br0
    EOF

# Install qemu, libvirt, etc.
yum install epel-release

yum install qemu-kvm libvirt bridge-utils 

# Install Webvirtmgr
yum install python-websockify libvirt-python libxml2-python python-pip

pip install numpy

cd webvirtmgr

manage.py run_gunicorn -c conf/gunicorn.conf.py

websockify 0.0.0.0:6080 127.0.0.1:5900

# Manually Configure VM profiles (could be useful in some case)
cd /etc/libvirt/qemu/

vi your-vm-name.xml
