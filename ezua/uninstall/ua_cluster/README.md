# Uninstall UA k8s cluster

## Introduction
The architecture overview for installation is below.

```
┌──────────────────┐             ┌──────────────────┐             ┌──────────────────┐
│                  │             │                  │             │                  │
│    Installer     │             │    Coordinator   │             │    UA Cluster    │
│    (Docker)      ├───install───► (Single node k8s)├───install───►   (k8s Cluster)  │
│                  │             │                  │             │                  │
└──────────────────┘             └──────────────────┘             └──────────────────┘
```
1. Booting installer on your Docker environment.
2. Install Coordinator node from the installer. This is a single node k8s.
3. Coordinator node is doing installation for UA cluster.

So we have to remove some k8s objects from Coordinator node when you need to uninstall UA cluster.

## Procedure
### On Coordinator Node
Remove all objects listed bewlo from Coordinator node by using *kubectl*.  
The target UA cluster name in this book is **hpe-ua**.  
* I have an alias of *kubectl* as *k*.

```bash
$ k get ezkfdeploys -A
NAMESPACE   NAME            CLUSTERNAME   WORKLOADTYPE   STATUS     FAILUREREASON   ADDITIONALINFO
ezkf-mgmt   ezkf-mgmt       ezkf-mgmt     ezfab          complete                   
hpe-ua      deploy-hpe-ua   hpe-ua        ezua           complete 

$ k delete ezkfdeploys -n hpe-ua deploy-hpe-ua

```
```bash
$ k get ezf -A
NAMESPACE   NAME        STATUS   CONTROLPLANE HOSTS   COMPUTE HOSTS   GPU HOSTS   STORAGE HOSTS
ezkf-mgmt   ezkf-mgmt   Ready    1                    0               0           0
hpe-ua      hpe-ua      Ready    3                    0               1           3

$ k delete -n hpe-ua ezf hpe-ua
 
```
```bash
$ k get ezkfclusters -A
NAMESPACE   NAME        AGE
ezkf-mgmt   ezkf-mgmt   15d
hpe-ua      hpe-ua      15d

$ k delete -n hpe-ua  ezkfclusters  hpe-ua  

```
```bash
$ k get ezkfclustercreates -A
NAMESPACE   NAME                        CLUSTERNAME   WORKLOADTYPE   STATUS     FAILUREREASON
hpe-ua      hpe-ua-2024-2-11-1-55-15    hpe-ua        ezua           complete  

$ k delete -n hpe-ua ezkfclustercreates hpe-ua-2024-2-11-1-55-15

```

Now UA cluster will be removed. Let's remove registered node hosts next.  
Remove all nodes associated UA cluster **hpe-ua**.  
DO NOT remove a node for **ezkf-mgmt**.  
Maybe it takes a while...

```bash
$ k get ezph -A
NAMESPACE            NAME             CLUSTER NAMESPACE   CLUSTER NAME   STATUS   VCPUS   UNUSED DISKS   GPUS
ezfabric-host-pool   172.18.106.150   ezkf-mgmt           ezkf-mgmt      Ready    4       0              0
ezfabric-host-pool   172.18.106.151   hpe-ua              hpe-ua         Ready    4       0              0
ezfabric-host-pool   172.18.106.152   hpe-ua              hpe-ua         Ready    4       0              0
ezfabric-host-pool   172.18.106.153   hpe-ua              hpe-ua         Ready    4       0              0
ezfabric-host-pool   172.18.106.161   hpe-ua              hpe-ua         Ready    32      1              0
ezfabric-host-pool   172.18.106.162   hpe-ua              hpe-ua         Ready    32      1              0
ezfabric-host-pool   172.18.106.163   hpe-ua              hpe-ua         Ready    32      1              0
ezfabric-host-pool   172.18.106.164   hpe-ua              hpe-ua         Ready    32      1              1

$ k delete ezph -n ezfabric-host-pool 172.18.106.151
$ k delete ezph -n ezfabric-host-pool 172.18.106.152
$ k delete ezph -n ezfabric-host-pool 172.18.106.153
$ k delete ezph -n ezfabric-host-pool 172.18.106.161
$ k delete ezph -n ezfabric-host-pool 172.18.106.162
$ k delete ezph -n ezfabric-host-pool 172.18.106.163
$ k delete ezph -n ezfabric-host-pool 172.18.106.164
```

And then remove namespace for UA cluster **hpe-ua**.  

```
$ k delete ns hpe-ua
```


### On UA Cluster Node
Remove all old setting files from each UA Cluster nodes(masters/control planes and workers).

```
/usr/local/bin/uninstall-ezkf-agent.sh 
rm -fr /etc/ezkf-agent
rm -fr /opt/ezkf
rm -fr /opt/ezkube/

yum erase -y kubectl kubeadm nerdctl containerd
rm -fr .kube/
rm -fr /var/lib/etcd/
rm -fr /var/lib/kubelet
rm -fr /etc/kubernetes/
rm -fr /var/lib/etcd/
rm -fr /etc/cni/net.d
rm -fr /var/lib/containerd/*
rm -fr /var/mapr
rm -fr /var/lib/calico
rm -fr /etc/containerd
rm -fr /opt/cni
rm -fr /opt/containerd
```

And format disk for the worker which was running DF.

```
$ fdisk /dev/<Your DF Raw Disk>
```

