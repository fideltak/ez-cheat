# Installation note on KVM
\* no need to do for EzUA 1.4
## Internal EDF disk
You may see CLDB *CrashLoopBackOff* during UA installation on the phase of set up EDF.

```bash
$ k get pod -n dataplatform
NAME                  READY   STATUS             RESTARTS        AGE
admincli-0            0/1     Running            0               23m
cldb-0                0/1     CrashLoopBackOff   7 (35s ago)     23m
cldb-1                1/1     Running            7 (6m7s ago)    23m
cldb-2                1/1     Running            7 (5m22s ago)   23m
init-fpkvw            0/1     Completed          0               24m
mcs-0                 0/1     Running            0               23m
objectstore-zone1-0   0/1     Init:0/1           0               19m
zk-0                  1/1     Running            0               24m
zk-1                  1/1     Running            0               23m
zk-2                  1/1     Running            0               23m
``` 

And you can see the line of error in cldb log like below.

```bash
2023/11/09 11:06:59 common.sh: [INFO] Contents of /opt/mapr/conf/disks.txt file:
/var/mapr/edf-disks/drive_hdd_0
/var/mapr/edf-disks/drive_hdd_0 failed. Error 19, No such device. Missing device file.
2023/11/09 11:07:06 common.sh: [WARNING] sudo -E -n /opt/mapr/server/disksetup failed with error code 1... Retrying in 10 seconds
2023/11/09 11:07:06 common.sh: [INFO] Force killing MFS service started by disksetup...
2023/11/09 11:07:06 common.sh: [INFO] Killing mfs service

```

This means there is no symboric link with raw disk.  
So need to make that symboric link for each workers running DF.  
Pls check the correct device file of DF raw disk.

```
ln -s /dev/disk/by-path/pci-0000:05:00.0 /var/mapr/edf-disks/drive_hdd_0
```