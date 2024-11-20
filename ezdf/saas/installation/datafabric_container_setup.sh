#!/bin/bash
#set -x
IMAGE="maprtech/edf-seed-container:latest"
INTERFACE="en0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage()
{
   echo "This script will deploy edf on seed node."
   echo
   echo "Syntax: ./datafabric_container_setup.sh [-i|--image] [-p|--publicipv4dns] [-f|--proxyfiledetails]"
   echo "options:"
   echo "-i|--image this is optional,By default it will pull image having latest tag,
         we can also provide image which has custom tag example:maprtech/edf-seed-container:7.8.0_9.3.0"
   echo "-p|--publicipv4dns is the public IPv4 DNS and needed for cloud deployed seed nodes. Note that both inbound and outbound trafic on port 8443
         needs to be enabled on the cloud instance. Otherwise, the Data Fabric UI cannot be acessible"
   echo "-f|--proxyfiledetails is the location of file from where proxy  details provided by user are copied to docker container."
   echo
}

os_name=$(. /etc/os-release  2> /dev/null && echo "$ID") &> /dev/null

install_docker_linux()
{
    echo "Docker is not present on the system. Installing it.."
    echo "Docker installation may take 6 to 8 minutes..."
    echo "There is no input/intervention required from user side"

    if [ $os_name == "ubuntu" ]; then
        sudo apt-get update > /dev/null
        sudo apt-get -y install ca-certificates curl gnupg > /dev/null
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -  > /dev/null 2>&1
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg trusted=yes] https://download.docker.com/linux/ubuntu \
            "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
        systemctl daemon-reload > /dev/null 2>&1
        systemctl restart docker  > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
    elif [ $os_name == "rhel" ]; then
       dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
       dnf install docker-ce --nobest -y > /dev/null
    elif [ $os_name == "centos" ]; then
       sudo yum install -y yum-utils > /dev/null
       sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
       sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi



sleep 120
systemctl start docker  > /dev/null 2>&1

#check if docker is installed and running
docker info > /dev/null 2>&1
if [ $? != 0 ] ; then
       echo
       echo "Docker installation on the node where this script is ran is not successfull. Please install docker manually to proceed forward"
       exit
else
      echo
      echo "Docker installation on node from script was successfull"
fi

}

#checking if required memory is present or not
os_vers=`uname -s` > /dev/null 2>&1
memory_requirement=1
if [ "$os_vers" == "Darwin" ]; then
     memory_available_mac=$(system_profiler SPHardwareDataType | grep "Memory" | awk '{print $2}')  &>/dev/null
       if  [ $memory_available_mac -lt 8 ] ; then
           echo -e "${GREEN}RAM NEEDED \t :\t 8 GB"
           echo -e "${RED}RAM AVILABLE \t :\t $memory_available_mac  GB"
           echo -e "${RED}Please try to spin up seed node on client having sufficient memory${NC}"
           memory_requirement=0
           exit
       fi
fi
if [ "$os_vers" == "Linux" ]; then
       memory_available_linux=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')  &>/dev/null
        if  [ $memory_available_linux -lt 8000000 ]; then
            echo -e "${GREEN}RAM NEEDED \t :\t 8 GB"
            echo -e "${RED}RAM AVAILABLE \t :\t $memory_available_linux"
            echo -e "${RED}Please try to spin up seed node on client having sufficient memory${NC}"
            memory_requirement=0
            exit
         fi
fi

#setting default value of container_engine to docker. Here container_engine refers to the container runtime installed.
container_engine='docker'

# Check if Docker is installed
docker info > /dev/null 2>&1
DOCKER_STATUS=$?

# Check if Podman is installed
podman info > /dev/null 2>&1
PODMAN_STATUS=$?

# If Podman is installed, set container_engine=podman
if [ $PODMAN_STATUS = 0 ]; then
    container_engine='podman'
    IMAGE="docker.io/maprtech/edf-seed-container:latest"
fi

# If docker is installed, set container_engine=docker
if [ $DOCKER_STATUS = 0 ]; then
    container_engine='docker'
fi



# If neither Docker nor Podman is available, install docker.
if [ $DOCKER_STATUS != 0 ] && [ $PODMAN_STATUS != 0 ]; then
    if [ "$os_vers" == "Darwin" ];then
    echo -e "${RED}Docker is not installed/not-running on the MacBook where this script is ran.Please install/start docker to proceed forward"
    echo -e "${GREEN}Reference link to install : https://docs.docker.com/desktop/install/mac-install/${NC}"
    exit
   elif [ "$os_vers" == "Linux" ]; then
         install_docker_linux
   fi
fi

#check connectivity to docker hub
container_engine_running=1
$container_engine run hello-world  > /dev/null 2>&1
if [ $? != 0 ]; then
    echo -e "${RED}$container_engine is not running on the system"
    echo -e "${RED}$container_engine is installed/running on the system but we are not able to pull images from docker"
    echo -e "${RED}Please check internet connectivity or if the machine is behind a proxy and take appropriate action accordingly${NC}"
    container_engine_running=0
    exit
fi

#remove the hello-world image we ran in earlier step
CID_Hello=$($container_engine ps -a | grep hello-world | awk '{ print $1 }' | tail -1  )
if [ -n "$CID_Hello" ]; then
   $container_engine stop $CID_Hello > /dev/null 2>&1
   $container_engine rm -f $CID_Hello > /dev/null 2>&1
fi

lsof_installed=1
if [ "$os_vers" == "Linux" ]; then
   if [ $os_name == "ubuntu" ] ; then
      if [ $(dpkg -l | grep -i lsof | wc -l) == 0 ]; then
          lsof_installed=0
      fi
   elif [ $os_name == "centos" ] || [ $os_name == "rhel" ]; then
        if [ $(rpm -qa | grep -i lsof | wc -l) == 0 ]; then
          lsof_installed=0
        fi
   fi
fi


if [ $lsof_installed == 1 ];then
    #check if ports used by datafabric is already used by some other process
    $container_engine ps -a | grep edf-seed-container > /dev/null 2>&1
    if [ $? != 0 ]; then
         seednodeports='7221 5660 5692 5724 5756 8443 8188 8080 7222 5181'
         pc=0
         for port in $seednodeports
            do
              result=`lsof -i:${port} | grep LISTEN`
              retval=$?
              if [ $retval -eq 0 ]; then
                 echo "${port} port is being used"
                 pc=1
              fi
            done
       if [ $pc -eq 1 ]; then
          echo -e "${RED}it seems to be that some existing application using the required ports so please make sure to clean them up before attempting again${NC}"
          exit 1
       fi
    fi
else
   echo -e "${YELLOW}lsof command is not installed on the system"
   echo -e "${YELLOW}We will not be able to check if ports 7221 5660 5692 5724 5756 8443 8188 8080 7222 5181 needed by Bootstrap node are being used by any other process/application"
   echo -e "${YELLOW}If above mentioned ports are in use then the container will fail to start${NC}"
fi

if [ $memory_requirement == 1 ]  && [ $container_engine_running == 1 ] && [ $lsof_installed == 1 ]; then
     echo -e "\t\t${GREEN}RAM NEEDED \t :\t AVAILABLE"
     echo -e "\t\t${GREEN}$container_engine STATUS \t :\t RUNNING"
     echo -e "\t\t${GREEN}PORTS NEEDED \t :\t AVAILABLE"
     echo -e "\t\tPROCEEDING FORWARD WITH DEPLOYING SEED NODE${NC}"
fi


while [ $# -gt 0 ]
do
  case "$1" in
  -i|--image) shift;
  IMAGE=$1;;
  -p|--publicipv4dns) shift;
  PUBLICIPV4DNS=$1;;
  -f|--proxyfiledetails) shift;
  PROXYFILEDETAILS=$1;;
  *) shift;
   usage
   exit;;
   esac
   shift
done

which ipconfig &>/dev/null
if [ $? -eq 0 ]; then
  INTERFACE=$(route -n get default | grep interface | awk '{print $2}')
  IP=$(ipconfig getifaddr $INTERFACE)
else
  INTERFACE=$(ip route | grep default | awk '{print $5}')
  IP=$(ip addr show $INTERFACE | grep -w inet | awk '{ print $2}' | cut -d "/" -f1)
fi
hostName="${hostName:-"edf-installer.hpe.com"}"
clusterName=$(echo ${hostName} | cut -d '.' -f 1)


runMaprImage() {
    echo "Please enter the local sudo password for $(whoami)"
        sudo rm -rf /tmp/maprdemo
        sudo mkdir -p /tmp/maprdemo/hive /tmp/maprdemo/zkdata /tmp/maprdemo/pid /tmp/maprdemo/logs /tmp/maprdemo/nfs
        sudo chmod -R 777 /tmp/maprdemo/hive /tmp/maprdemo/zkdata /tmp/maprdemo/pid /tmp/maprdemo/logs /tmp/maprdemo/nfs

        PORTS=' -p 2222:22 -p 7221:7221  -p 5660:5660 -p 8443:8443  -p 8080:8080  -p 8188:8188  -p 7222:7222 -p 5181:5181  -p 5692:5692 -p 5724:5724 -p 5756:5756 '
        #export MAPR_EXTERNAL="0.0.0.0"
  #incase non-mac ipconfig command would not be found
  which ipconfig &>/dev/null
  if [ $? -eq 0 ]; then
    export MAPR_EXTERNAL=$(ipconfig getifaddr $INTERFACE)
  else
    export MAPR_EXTERNAL=$(ip addr show $INTERFACE | grep -w inet | awk '{ print $2}' | cut -d "/" -f1)
  fi


  if [ "${PUBLICIPV4DNS}" == "" ]; then
        echo ""
  else
    export PUBLICIPV4DNS="${PUBLICIPV4DNS}"
  fi

        $container_engine pull ${IMAGE};
        $container_engine run -d --privileged -v /tmp/maprdemo/zkdata:/opt/mapr/zkdata -v /tmp/maprdemo/pid:/opt/mapr/pid  -v /tmp/maprdemo/logs:/opt/mapr/logs  -v /tmp/maprdemo/nfs:/mapr $PORTS -e MAPR_EXTERNAL -e clusterName -e isSecure --hostname ${clusterName} ${IMAGE} > /dev/null 2>&1

   # Check if container is started wihtout any issue
   sleep 5 # wait for container to start

    CID=$($container_engine ps -a | grep edf-seed-container | awk '{ print $1 }' )
    RUNNING=$($container_engine inspect --format="{{.State.Running}}" $CID 2> /dev/null)
    ERROR=$($container_engine inspect --format="{{.State.Error}}" $CID 2> /dev/null)

    if [ "$RUNNING" == "true" -a "$ERROR" == "" ]
    then
            echo "Developer Sandbox Container $CID is running.."
    else
            echo "Failed to start Developer Sandbox Container $CID. Error: $ERROR"
            exit
    fi
}

$container_engine ps -a | grep edf-seed-container > /dev/null 2>&1
if [ $? -ne 0 ]
then
        STATUS='NOTRUNNING'
else
        echo "MapR sandbox container is already running."
        echo "1. Kill the earlier run and start a fresh instance"
        echo "2. Reconfigure the client and the running container for any network changes"
        echo -n "Please enter choice 1 or 2 : "
        read ANS
        if [ "$ANS" == "1" ]
        then
                CID=$($container_engine ps -a | grep edf-seed-container | awk '{ print $1 }' )
                $container_engine stop $CID > /dev/null 2>&1
                $container_engine kill $CID > /dev/null 2>&1
                $container_engine rm -f $CID > /dev/null 2>&1
                STATUS='NOTRUNNING'
        else
                STATUS='RUNNING'
        fi
fi

if [ "$STATUS" == "RUNNING" ]
then
        # There is an instance of dev-sandbox-container. Check if it is running or not.
        CID=$($container_engine ps -a | grep edf-seed-container | awk '{ print $1 }' )
        RUNNING=$($container_engine inspect --format="{{.State.Running}}" $CID 2> /dev/null)
        if [ "$RUNNING" == "true" ]
        then
                # Container is running there.
                # Change the IP in /etc/hosts and reconfigure client for the IP Change
                # Change the server side settings and restart warden
                grep ${hostName} /etc/hosts | grep ${IP} > /dev/null 2>&1
                if [ $? -ne 0 ]
                then
                        echo "Please enter the local sudo password for $(whoami)"
                        sudo sed -i  '/'${hostName}'/d' /etc/hosts &>/dev/null
                        sudo  sh -c "echo  \"${IP}      ${hostName}  ${clusterName}\" >> /etc/hosts"
                        sudo sed -i '' '/'${hostName}'/d' /opt/mapr/conf/mapr-clusters.conf &>/dev/null
                        sudo /opt/mapr/server/configure.sh -c -C ${hostName}  -N ${clusterName} > /dev/null 2>&1
                        # Change the external IP in the container
                        echo "Please enter the root password of the container 'mapr' "
                        ssh root@localhost -p 2222 " sed -i \"s/MAPR_EXTERNAL=.*/MAPR_EXTERNAL=${IP}/\" /opt/mapr/conf/env.sh "
                        echo "Please enter the root password of the container 'mapr' "
                        ssh root@localhost -p 2222 "service mapr-warden restart"
                fi
        fi
        if [ "$RUNNING" == "false" ]
        then
                # Container was started earlier but is not running now.
                # Start the container. Change the client side settings
                # Change the server side settings
                $container_engine start ${CID}
                echo "Please enter the local sudo password for $(whoami)"
                sudo sed -i  '/'${hostName}'/d' /etc/hosts &>/dev/null
                sudo sh -c "echo  \"${IP}       ${hostName}  ${clusterName}\" >> /etc/hosts"
                sudo sed -i '' '/'${hostName}'/d' /opt/mapr/conf/mapr-clusters.conf &>/dev/null
        sudo /opt/mapr/server/configure.sh -c -C ${hostName}  -N ${clusterName} > /dev/null 2>&1
        # Change the external IP in the container
                echo "Please enter the root password of the container 'mapr' "
                ssh root@localhost -p 2222 " sed -i \"s/MAPR_EXTERNAL=.*/MAPR_EXTERNAL=${IP}/\" /opt/mapr/conf/env.sh "
                echo "Please enter the root password of the container 'mapr' "
        ssh root@localhost -p 2222 "service mapr-warden restart"
        fi
else
        # There is no instance of dev-sandbox-container running. Start a fresh container and configure client.
        runMaprImage

        sudo sed -i  '/'${hostName}'/d' /etc/hosts &>/dev/null

        os_vers=`uname -s` > /dev/null 2>&1

        `$container_engine cp $CID:/etc/environment /tmp/proxyseednode`
        `echo "export SEED_NODE=true" >> /tmp/proxyseednode` > /dev/null 2>&1

        if [ "$os_vers" == "Darwin" ]; then
           if [ "${PROXYFILEDETAILS}" != "" ]; then
                `cat $PROXYFILEDETAILS >>/tmp/proxyseednode` > /dev/null 2>&1
           fi
        fi
        if [ "$os_vers" == "Linux" ]  && [ "${PROXYFILEDETAILS}" != "" ]; then
           `cat $PROXYFILEDETAILS >>/tmp/proxyseednode` > /dev/null 2>&1
        fi
        if  [ "$os_vers" == "Linux" ]  && [ "${PROXYFILEDETAILS}" == "" ]; then
           `cat /etc/environment >>/tmp/proxyseednode` > /dev/null 2>&1
           `cat /etc/profile.d/proxy.sh >>/tmp/proxyseednode` > /dev/null 2>&1
        fi
        `$container_engine cp /tmp/proxyseednode $CID:/etc/environment` > /dev/null 2>&1
        `rm -rf /tmp/proxyseednode` > /dev/null 2>&1
        services_up=0
        sleep_total=600
        sleep_counter=0
        if [ "$os_vers" == "Darwin" ]; then
           while [[ $sleep_counter -le $sleep_total ]]
            do
             curl -k -X GET "https://edf-installer.hpe.com:8443/rest/node/list?columns=svc" -u mapr:mapr123 &>/dev/null
             if [ $? -ne 0 ];then
                echo "services required for Ezmeral Data fabric are  coming up"
                sleep 60;
                sleep_counter=$((sleep_counter+60))
             else
                services_up=1
                break
             fi
           done
       fi
       if [ "$os_vers" == "Linux" ]; then
           while [[ $sleep_counter -le $sleep_total ]]
            do
             curl -k -X GET https://`hostname -f`:8443/rest/node/list?columns=svc -u mapr:mapr123 &>/dev/null
             if [ $? -ne 0 ];then
                echo "services required for Ezmeral Data fabric are  coming up"
                sleep 60;
                sleep_counter=$((sleep_counter+60))
             else
                services_up=1
                break
             fi
           done
       fi


        if [ $services_up -eq 1 ]; then
           echo
           echo "Client has been configured with the $container_engine container."
           echo
           if [   "${PUBLICIPV4DNS}" == "" ]; then
                echo "Please click on the link https://"${MAPR_EXTERNAL}":8443/app/dfui to deploy data fabric"
                echo "For user documentation, see https://docs.ezmeral.hpe.com/datafabric/home/installation/installation_main.html"
                echo
           else
                echo "Please click on the link  https://"${PUBLICIPV4DNS}":8443/app/dfui  to deploy data fabric"
                echo "For user documentation, see https://docs.ezmeral.hpe.com/datafabric/home/installation/installation_main.html"

          fi
       else
          echo
          echo "services didnt come up in stipulated 10 mins time"
          echo "please login to the container using ssh root@localhost -p 2222 with mapr as password and check further"
          echo "For documentation on steps to debug, see https://docs.ezmeral.hpe.com/datafabric/home/installation/troubleshooting_seed_node_installation.html"
          echo "once all services are up fabric UI is available at https://"${MAPR_EXTERNAL}":8443/app/dfui  and fabrics can be deployed from that page"
          echo
       fi


fi
