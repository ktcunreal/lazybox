# Kubernetes Ops Practice

# 1. Build HA Kubernetes cluster with external etcd 

## Objective: 
- Set up 3 etcd node
- Set up 3 master node
- Set up 3 worker node
- Set up haproxy with KA for endpoint & load balancer
-  Set up prometheus for cluster monitoring

## 1.0. Start from scratch

### Install VM Software

Get Virtualbox from https://www.virtualbox.org/wiki/Downloads

Download extension pack as well

    VBoxManage extpack install "correspond-version-of-extension-pack"
    VBoxManage list extpacks

If you don't have a X Window system, running a web UI in docker container would be nice (optional)

https://hub.docker.com/r/theadribreezy/phpvirtualbox

https://hub.docker.com/r/joweisberg/phpvirtualbox

Add a user for running Virtualbox-web UI backend (optional)

    useradd virtualbox
    passwd virtualbox
    su virtualbox -c "vboxwebsrv --host 0.0.0.0"

### Set bridge network

NetworkManager are included on most Linux distribution.

Follow instruction of `nmtui` to configure a bridge network.

### Create VMs

    Virtualization Platform: Oracle Virtualbox 6.1.26 (KVM)
    CPU: 2 vCPU (x86_64)
    Mem: 4096 MB
    vHDD: 50 GB 
    Distribution: CentOS 7.9 net-inst
    Network: Bridge (Promiscuous mode, allow all)

### Update everything, Install basic components

    yum remove firewalld -y
    yum update -y
    yum install -y  wget chrony yum-utils device-mapper-persistent-data lvm2 iptables-services nfs-utils
    systemctl enable chronyd --now

## 1.1.  Install & configure haproxy

    yum install haproxy -y

Edit /etc/haproxy/haproxy.cfg

    defaults
        mode          tcp
        option        dontlognull
        timeout         connect         15s
        timeout         server          30s
        timeout         client          30s
        maxconn         51200
        retries             3

    frontend  main
      bind        *:6443
        default_backend             k8smaster

    backend k8smaster
        balance static-rr
        server      centos-01   192.168.0.201:6443 check rise 2 fall 3 inter 4s weight 40
        server      centos-02   192.168.0.202:6443 check rise 2 fall 3 inter 4s weight 40
        server      centos-03   192.168.0.204:6443 check rise 2 fall 3 inter 4s weight 20

## 1.2. Install Keepalived

    yum install keepalived ipvsadm -y
    vi /etc/keepalived/keepalive.conf

Master

    global_defs {
        router_id LVS_DEVEL
    }
    vrrp_script check_bg {
        script "/usr/bin/curl -k --connect-timeout 5 --max-time 15 https://localhost:6443/healthz"
        interval 1
        rise 2
        fall 3
        weight -10
    }
    vrrp_instance VI_1 {
        state MASTER
        interface enp0s3
        virtual_router_id 100
        priority 100
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass centos
        }
        virtual_ipaddress {
            192.168.0.150/32 dev enp0s3
        }
        track_script {
            check_bg
        }
    }

Backup

    global_defs {
        router_id LVS_DEVEL
    }
    vrrp_script check_bg {
        script "/usr/bin/curl -k --connect-timeout 5 --max-time 15 https://localhost:6443/healthz"
        interval 1
        rise 2
        fall 3
        weight -10
    }
    vrrp_instance VI_1 {
        state BACKUP
        interface enp0s3
        virtual_router_id 100
        priority 99
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass centos
        }
        virtual_ipaddress {
            192.168.0.150/32 dev enp0s3
        }
        track_script {
            check_bg
        }
    }

## 1.3. Install etcd cluster

    yum install etcd -y; systemctl enable etcd

Follow [etcd clustering guide](https://etcd.io/docs/v3.3/op-guide/clustering/#etcd-discovery) to set params in /etc/etcd/etcd.conf

Managing certificate for etcd cluster could be an extremly pain in the ass. It is a good choice to use [cfssl/cfssljson](https://github.com/coreos/docs/blob/master/os/generate-self-signed-certificates.md) tools . See  section **Generate certificates for etcd** for detail.

In non-production environment, skip certificate setup (use plain http)  could save plenty of time. 

## 1.4. Install Docker & Kubernetes

### Disable SELinux & swap, set kernel param

Check /etc/fstab for swap partition and turn it off.
    
    setenforce 0
    sed -i 's^SELINUX=enforcing$SELINUX=disable/' /etc/selinux/config

    cat << EOF >> /etcsysctl.conf
    net.bridgebridge-nf-call-ip6tables= 1
    net.bridgebridge-nf-call-iptables= 1
    net.bridgebridge-nf-call-arptables= 1
    net.ipv4.ip_forward=1
    EOF

    sysctl -p

Reboot

### Add Docker, Kubernetes repo

    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

~~*Official repo, hard to connect in some country. Please check bindary integrity when downloading from untrusted source*~~

    cat << EOF >> /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    EOF 

~~*Official repo, impossible to connect in some country. Please check bindary integrity when downloading from untrusted source*~~

### Add Docker, Kubernetes repo (Alternative)

    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
###
    cat << EOF >> /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
    EOF

### Install & Enable docker service
    
    yum install docker-ce docker-ce-cli containerd.io -y; systemctl enable --now docker

### Install & Enable Kubernetes service

    yum install -y kubelet kubeadm kubectl 
    systemctl enable iptables --now
    systemctl enable kubelet

## 1.5. Set Control plane 1

### Check etcd, docker, kubernetes installation

1. Finish docker & kubernetes installation on all machines
2. Check network connectivities between each node 
3. Make sure individual hostname is set for each machine. Edit /etc/hosts

### Get essential images

1. kubeadm config images list
2. docker pull registry.aliyuncs.com/google_containers/img:tag
3. docker tag registry.aliyuncs.com/google_containers/img:tag k8s.gcr.io/img:tag

### Start kubelet

1. Check kubelet exec cgroup-driver argument(/usr/lib/systemd/system/kubelet.service) 
2. `kubeadm init phase kubelet-start`

### Generate certificates

1. `kubeadm init phase certs all --control-plane-endpoint "192.168.0.203:6443" --apiserver-cert-extra-sans "ip_01,ip_02,ip_03,domain_01,domain_02,domain_03"` 

- (or `'kubeadm init phase certs all --config kubeadm-config.yaml'`)

### Generate kubeconfig & control-plane manifests
1. `kubeadm init phase kubeconfig all --control-plane-endpoint "192.168.0.203:6443"`
2. `kubeadm init phase control-plane all --control-plane-endpoint "192.168.0.203:6443"`

### Upload config & certs
1. `kubeadm init phase upload-config all`

    - kubectl -n kube-system get cm kubeadm-config

    - Edit kubeadm-config.yaml

        ```
           apiServer:
           certSANs:
           - "192.168.0.201"
           - "127.0.0.1"
           - "centos-01"
          - "localhost"
         controlPlaneEndpoint: 192.168.0.203:6443
           etcd:
            external:
               endpoints:
              - http://192.168.0.201:2379
              - http://192.168.0.202:2379
             - http://192.168.0.203:2379
            caFile: /etc/kubernetes/pki/etcd/ca.crt
            certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
            keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
        ```

2. `kubeadm init phase upload-certs --upload-certs --config kubeadm-config.yaml`

    **(Save returned certificate-key string for later use)**

### Updates kubelet settings
- (Optional) kubeadm init phase mark-control-plane; 
- (Optional) kubeadm init phase bootstrap-token
- (Optional)kubectl taint nodes centos-01 node-role.kubernetes.io/master=:NoSchedule
- `kubeadm init phase kubelet-finalize all`

 ### Deploy cni plugin, coredns, kubeproxy
1. Get flannel or calico.yaml from official link
- https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
- https://docs.projectcalico.org/manifests/calico.yaml
2. `kubectl apply -f calico.yaml (flannel.yaml)`
3. `kubeadm init phase addon all --control-plane-endpoint "192.168.2.203:6443"`

## 1.6. Set Control plane 2, 3

Control plane 1
    
    kubeadm token create --print-join-command

Control plane 2, 3
        
    kubeadm join 192.168.0.203:6443 --control-plane --certificate-key xxxxxxxx --token xxxxxxxx --discovery-token-ca-cert-hash sha256:xxxxxxxx

redo ***Set Control plane 1:  Upload certs*** if certificate-key expired

## 1.7. Set Worker node 1, 2, 3

Control plane
    
    kubeadm token create --print-join-command

Worker node 1, 2, 3

    kubeadm join 192.168.0.203:6443 --token xxxxxxxx --discovery-token-ca-cert-hash sha256:xxxxxxxx




# 2.0. Running apps and services in kubernetes

## 2.1. Deployment

	kind: Deployment
	apiVersion: apps/v1
	metadata:
	  name: {{ PROJECT }}
	spec:
	  replicas: 1 
	  selector:
	    matchLabels:
	      app: {{ PROJECT }}
	  template:
	    metadata:
	      labels:
	        app: {{ PROJECT }}
	    spec:
	      containers:
	      - name: {{ PROJECT }}
	        image: {{ REGISTRY_ADDR }}/{{ PROJECT }}:{{ RELEASE }}
	        ports:
	        - containerPort: 8080
	        volumeMounts:
	        - name: {{ PROJECT }}-PV
	          mountPath: /data/
	      volumes:
	      - name:  {{ PROJECT }}-PV
	        persistentVolumeClaim:
	          claimName: PVC-001

## 2.2. Services

	apiVersion: v1
	kind: Service
	metadata:
	  name: {{ PROJECT }}
	spec:
	  ports:
	  - name: http
	    targetPort: 8080
	    port: 8080
	  selector:
	    app: {{ PROJECT }}

## 2.2. PV & PVC

Using NFS as PV provisioner

    systemctl enable nfs --now

vi /etc/exports

    /data   192.168.0.0/24(rw,all_squash,anonuid=65534,anongid=65534,no_subtree_check)

exportfs -rv

PV & PVC.yaml
	
	apiVersion: v1
	kind: PersistentVolume
	metadata:
	  name: PV-001
	  labels:
	    id: centos-01
	spec:
	  capacity:
	    storage: 20Gi
	  accessModes:
	  - ReadWriteMany
	  persistentVolumeReclaimPolicy: Retain
	  nfs:
	    path: /data
	    server: 192.168.0.203
	  mountOptions:
             - v4.2

	---
	
	apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  name: PVC-001
	spec:
	  selector:
	    matchLabels:
	      id: centos-01
	  accessModes:
	    - ReadWriteMany
	  resources:
	    requests:
	      storage: 1Gi

## 2.4. Statefulset

	apiVersion: v1
	kind: Service
	metadata:
	  name: nginx
	  labels:
	    app: nginx
	spec:
	  ports:
	  - port: 80
	    name: web
	  clusterIP: None
	  selector:
	    app: nginx
	---
	apiVersion: apps/v1
	kind: StatefulSet
	metadata:
	  name: web
	spec:
	  selector:
	    matchLabels:
	      app: nginx
	  serviceName: "nginx"
	  replicas: 3
	  template:
	    metadata:
	      labels:
	        app: nginx
	    spec:
	      terminationGracePeriodSeconds: 5
	      containers:
	      - name: nginx
	        image: nginx:1.20-alpine
	        ports:
	        - containerPort: 80
	          name: web
	        volumeMounts:
	        - name: www
	          mountPath: /usr/share/nginx/html
              # subPath: html
              subPathExpr: $(POD_NAME)
	      volumes:
	        - name: www
	          persistentVolumeClaim:
	            claimName: pvc-001

# 3.0. Cluster monitoring

## Metrics-server

    https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Add "--kubelet-insecure-tls" to container args.

Now you can run `kubectl top node / kubectl top pod` for monitoring cluster resource usage.

## Install Prometheus components

Download Prometheus, Alertmanager, exporter you need from

    https://prometheus.io/download/

Get Kube-state-metrics (This is NOT Metrics-server!)

    https://github.com/kubernetes/kube-state-metrics/tree/master/examples/standard

*In some country you need to pull kube-state-metrics image via proxy*

Promethus.yml

	global:
	  scrape_interval: 15s 
	  evaluation_interval: 15s 
	
	alerting:
	  alertmanagers:
	    - static_configs:
	        - targets:
	          - localhost:9093
	
	rule_files:
	  - "../rules/default.yml"
	
	scrape_configs:
	  - job_name: "prometheus"
	    static_configs:
	      - targets: ["localhost:9090"]
	
	  - job_name: 'blackbox'
	    metrics_path: /probe
	    params:
	      module: [http_2xx] 
	    static_configs:
	      - targets:
	        - http://prometheus.io
	        - https://prometheus.io
	    relabel_configs:
	      - source_labels: [__address__]
	        target_label: __param_target
	      - source_labels: [__param_target]
	        target_label: instance
	      - target_label: __address__
	        replacement: 192.168.0.201:9115 # The blackbox exporter's real hostname:port
	
	  - job_name: "kube-state-metrics"
	    static_configs:
	      - targets: ["kube-state-metrics.kube-system:8080"]

AlertManager.yml

	route:
	  group_by: ['alertname']
	  group_wait: 30s
	  group_interval: 2m
	  repeat_interval: 30m
	  receiver: email
	
	receivers:
	- name: email
	  email_configs:
	  - to: someone@somewhere.com
	    from: someone@somewhere.com
	    smarthost: smtp.exmail.qq.com:465
	    auth_username: someone@somewhere.com
	    auth_password: 220051
	    require_tls: false
	    send_resolved: true

blackbox.yml

	modules:
	  http_2xx:
	    prober: http
	    http:
	      tls_config:
	        insecure_skip_verify: true
	  http_post_2xx:
	    prober: http
	    http:
	      method: POST
	  tcp_connect:
	    prober: tcp
	  icmp:
	    prober: icmp

rules.yml

	groups:
	- name: default
	  rules:
	  - alert: ServiceDown
	    expr: probe_http_status_code{instance="https://192.168.0.201:6443/healthz"}!=200
	    for: 30s
	    labels:
	      severity: warn
	    annotations:
	      summary: "{{ $labels.instance }} Down"

# 4.0. Simple integrate with Jenkins & Ansible

## 4.1.  Set up ansible

`yum install ansible -y`

Playbook directory layout example:

    /etc/ansible/project_dir/
        hosts.dev
        hosts.prod
        playbook.yml
        group_vars/
          all
          group_name
        roles/
          deploy/
            files/
              essentials.txt
            tasks/
              main.yml
            templates/
              application.conf

hosts
  
    [parent:children]
    child

    [child]
    192.168.0.201 ansible_ssh_host=192.168.0.201 ansible_ssh_user='root' ansible_ssh_pass='centos'

playbook.yml

    - name: playbook main stage
      hosts: parent
      remote_user: root
      roles:
      - deploy

roles/deploy/tasks/main.yml

    - name: Create project directory
      file: 
        state=directory 
        mode=0755 
        path=/data/tmp/{{ FOO }}
      tags: deploy

    - name: Upload yml
      template: 
        src=test.yml                  
        dest=/data/tmp/{{ FOO }}/deployment.yml
      tags: deploy

    - name: Copy file with owner and permissions
      copy:
        src: test.file
        dest: /data/tmp/{{ FOO }}/test.file
        owner: tomcat
        group: tomcat
        mode: 0644
      tags: deploy

    - name: deploy
      shell: /usr/bin/kubectl apply -f /data/tmp/deployment.yaml
      tags:
      - deploy

## 4.2. Set up jenkins

Go to https://www.jenkins.io/download/

`java -jar jenkins.war --httpPort=9090`

Install jenkins extensions:
- Ansible plugin
- Build Pipeline Plugin
-	Folders Plugin
-	Parameterized Trigger plugin
- Role-based Authorization Strategy
-	Workspace Cleanup Plugin

Job -> Build step -> Invoke Ansible Playbook

Fill in Playbook path & Inventory path

Enjoy

# 5.0. Useful tricks

### Create container using macvlan network

	docker network create -d macvlan \
			--subnet $SUBNET \
			--gateway- $GATEWAY \
			-o parent=$NETWORK_INTERFACE \
			-o macvlan_mode=bridge \
			 $NETWORK_NAME

	docker create --ip $CONTAINER_IP \
			--network $NETWORK_NAME \
			--name $CONTAINER_NAME \
			-h $HOSTNAME \
			$IMAGE_ID \
			/usr/sbin/init

Due to macvlan's design, container is unable to connect host through original ip (vice versa), we can create a dummy dev and assign another ip for host.

    ip link add dummy link enp5s0 type macvlan mode bridge
    ip addr add 192.168.0.254/32 dev dummy
    ip link set dummy up
    ip route add 192.168.0.84/32 dev dummy

Now the host machine is able to communicate with the container via dummy ip address. 

### Fast reload kubernetes/manifest, cni configs, regenerate routing rules (for broken networking on some node)

    systemctl stop kubelet
    systemctl stop docker
    iptables --flush
    iptables -tnat --flush
    systemctl start docker
    systemctl start kubelet

### Visit cluster resources from external machine

Check service-cidr

    kubectl get svc -n kube-system

    grep service-cluster-ip-range /etc/kubernetes/manifests/kube-apiserver.yaml 

    calicoctl get ippool (if using calico)

Add routing rule 

    ip route add 10.96.0.0/12 via 192.168.1.100 (default service-cidr)
    ip route add 10.244.0.0/16 via 192.168.1.100 (default flannel-pod-cidr)

Add DNS Server

    echo "nameserver 10.96.0.10" >> /etc/resolv.conf
    echo "search default.svc.cluster.local svc.cluster.local cluster.local" >> /etc/resolv.conf

***Routing rules will be lost after system reboot***

### Port-forward for pod debugging

    kubectl port-forward --address 0.0.0.0 pods/podname-abcde-qwert 8080:8080

Or

    kubectl port-forward --address 0.0.0.0 deployment/name  8080:8080

Debug your application at \<control-plane-ip\>:port

### Get discovery-token-ca-cert-hash

    openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -pubkey | openssl rsa -pubin -outform DER 2>/dev/null | sha256sum

### Generate Certificates for etcd
    
    echo '{"CN":"CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare ca -
    echo '{"signing":{"default":{"expiry":"87600h","usages":["signing","key encipherment","server auth","client auth"]}}}' > ca-config.json
    export ADDRESS=127.0.0.1,localhost,::1,192.168.0.201,192.168.0.202,192.168.0.203,192.168.0.204,centos-01,centos-02,centos-03,centos-04
    echo '{"CN":"etcd","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare etcd

### Combine multiple admin profile

Edit ~/.kube/config

    apiVersion: v1

    clusters:
    - cluster:
        certificate-authority-data: aaaaaaaa
        server: https://192.168.3.16:6443
    name: kubernetes-1
    - cluster:
        certificate-authority-data: bbbbbbbb
        server: https://192.168.1.100:6443
    name: kubernetes-2

    users:
    - name: kubernetes-admin-1
        user:
            client-certificate-data: aaaa
            client-key-data: aaaa
    - name: kubernetes-admin-2
        user:
            client-certificate-data: cccccccc
            client-key-data: dddddddd

    contexts:
    - context:
            cluster: kubernetes-1
            user: kubernetes-admin-1
        name: kubernetes-admin-1@kubernetes-1
    - context:
            cluster: kubernetes-2
            user: kubernetes-admin-2
        name: kubernetes-admin-2@kubernetes-2
    
    current-context: kubernetes-admin-1@kubernetes-1
    kind: Config
    preferences: {}

Switch profile with

    kubectl config get-contexts
    kubectl config set-contexts

### Graceful terminating pod

Pod term lifecycle:

1. Pod is set to the “Terminating” State and removed from the endpoints list of all Services
2. preStop Hook is executed
3. SIGTERM signal is sent to the pod
4. Kubernetes waits for a grace period
5. SIGKILL signal is sent to pod, and the pod is removed

If your application does not gracefully shut down when receiving a SIGTERM you can use this hook to trigger a graceful shutdown. Most programs gracefully shut down when receiving a SIGTERM, but if you are using third-party code or are managing a system you don’t have control over, the preStop hook is a great way to trigger a graceful shutdown without modifying the application.

Kubernetes waits for a specified time called the termination grace period. By default, this is 30 seconds. It’s important to note that this happens in parallel to the preStop hook and the SIGTERM signal. Kubernetes does not wait for the preStop hook to finish.

    apiVersion: v1
    kind: Pod
    metadata:
        name: my-pod
    spec:
        containers:
        - name: blabla
           image: blabla
        terminationGracePeriodSeconds: 60s

### To clean docker registry
    # Path to repositories
    BASEDIR=/var/lib/registry/docker/registry/v2/repositories

    # How many builds to keep
    BUILDNUM=5

    # Delete files
    for ln in `ls -1 $BASEDIR`;do
    # Keep BUILDNUM for each project
    cd $BASEDIR/$ln/_manifests/tags && ls -1t |awk '{if (NR>$BUILDNUM){print $1}}'|xargs rm -rf;
    cd $BASEDIR/$ln/_manifests/revisions/sha256 && ls -1t |awk '{if (NR>BUILDNUM){print $1}}'|xargs rm -rf;
    done;

    # Clean registry
    registry garbage-collect /etc/docker/registry/config.yml


## Troubleshooting


### Corrupted etcd node recovering

1. Remove unhealth member from etcd cluster

        etcdctl member list
        etcdctl member remove corrupted_member

2. Re-add member to cluster

       etcdctl member add "member_name" "peerUrl"
    Copy returned env varible

3. On  corrupted node 
    
        systemctl stop etcd
        rm -rf /var/lib/etcd/* (ETCD_DATA_DIR)
        vim /etc/etcd/etcd.conf
        
    Paste env varibles from 2nd step, overwrite original value

        ETCD_NAME=
        ETCD_INITIAL_CLUSTER=
        ETCD_INITIAL_CLUSTER_STATE=existing


### Change etcd peer listen address

***NEITHER 'ETCD_LISTEN_PEER_URLS' IN etcd.conf , NOR  CMDLINES IN [OFFICIAL DOC](https://etcd.io/docs/v3.3/op-guide/runtime-configuration) WORKS. THEY WON'T DO ANY SHIT.*** 

> ~~etcdctl member update xxxxxx --peer-urls=http://10.0.1.10:2380~~

Use following command:

> etcdctl member update xxxxxx https://192.168.0.201:2380

******

## Reference

[Kubeadm](https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init-phase/)

[Calico](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises)

[Etcd](https://etcd.io/docs/v3.3/op-guide/clustering/#etcd-discovery)

[Graceful terminate pod](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-terminating-with-grace)