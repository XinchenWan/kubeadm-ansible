#!/bin/bash

# IP allocation-rule:   Controller_i = 10.40.0.2 ~ 10.40.0.127                Controller_max=126
#                       Deploy = 10.40.128
#                       Worker_i = 10.40.0.129 ~ 10.40.0.254                  Worker_max=126              including cpu instances and gpu instances
#                       Worker_pod_i = 10.20.${Worker_i}.1 ~ 10.20.${Worker_i}.254        Worker_i=129～254
#                       Each worker_node contains 254 pods at most
#                       10.42.0.1 is the GenericAPIServer service IP
#                       10.30.0.0/24  for nfs, ldap, docker registry

GCP_CREDENTIAL=${1:-${STARCLOUD_CREDENTIAL}}
GCP_PROJECT=${2:-${STARCLOUD_ID}}
CONTROLLER_NODES=${3:-1}
WORKER_GPU_NODES=${4:-0}
WORKER_CPU_NODES=${5:-4}
PASSWORD_PASSPHRASE=${6:-"123456"}

GCP_REGION=asia-east1
GCP_ZONE=asia-east1-a

WORKER_SUM_NODES=`expr ${WORKER_GPU_NODES} + ${WORKER_CPU_NODES}`

WAN_TEST_GCP_CREDENTIAL=~/Downloads/NebulaCloud-f91743b4353e.json
WAN_FALSE_GCP_CREDENTIAL=~/Downloads/FALSENebulaCloud-a29d053f42a6.json
WAN_FIRSTPROJECT_API_CREDENTIAL=/Users/nebula/Desktop/'APIMyFirstProject-92c62bb05cb3.json'

WAN_NEBULACLOUD_ID=nebulacloud-197608
WAN_NEBULACLOUD_FALSE_ID=nebula-cloud-197510
WAN_FIRSTPROJECT_ID=studious-rhythm-197504


VPC_NAME=kubernetes-the-hard-way
VPC_SUBNET_NAME=kubernetes
# VPC_SUBNET_NECESSARY_NAME=necessary
IP_POOL=10.240.0.0/24
# NECESSARY_IP_POOL=10.230.0.0/24
POD_IP_POOL=10.200.0.0/16
SERVICE_CLUSTER_IP_POOL=10.32.0.0/24

PREFIX3_IP_POOL=10.240.0.
# PREFIX3_NECESSARY_IP_POOL=10.230.0.
PREFIX2_POD_IP_POOL=10.200.
PREFIX3_SERVICE_CLUSTER_IP_POOL=10.32.0.

CONTROLLER_NAME=controller-
WORKER_CPU_NAME=worker-cpu-
WORKER_GPU_NAME=worker-gpu-
NFS_SERVER_NAME=nfs-server
LDAP_SERVER_NAME=ldap-server

CONTROLLER_IP_LIST=
WORKER_GPU_IP_LIST=
WORKER_CPU_IP_LIST=
WORKER_IP_LIST=
WORKER_POD_LIST=
ETCD_LIST=
# etcd_list https://10.240.0.2:2379,https://10.240.0.3:2379,https://10.240.0.4:2379,https://10.240.0.5:2379
# worker pod ip to be allocated

FIREWALL_INTERNAL_NAME=kubernetes-the-hard-way-allow-internal
FIREWALL_EXTERNAL_NAME=kubernetes-the-hard-way-allow-external

CA_DIRECTORY=CA_Registry
KUBECONFIG_DIRECTORY=Kubeconfig_Registry
ENCRYPT_DIRECTORY=Encrypt_yaml
EXP_DIRECTORY=exp_Registry
CONTROLLER_IP_TABLE=controller_ip_table.txt
WORKER_IP_TABLE=worker_ip_table.txt
WORKER_POD_IP_TABLE=worker_pod_ip_table.txt

validate_environment(){
    # Check if gcloud exists
    printf "Checking if gcloud exists...\n"
    command -v gcloud > /dev/null 2>&1 || { echo >&2 -e "Google Cloud SDK required - doesn't seem to be on your path. Aborting...\n"; exit 1; }
    
    # Check if project exists
#     printf "Checking if project $WAN_NEBULACLOUD_ID exists...\n"
#     command gcloud projects describe $WAN_NEBULACLOUD_ID || { echo >&2 "Project $WAN_NEBULACLOUD_ID not exists...\n"; exit 1;}
#     command gcloud projects describe $WAN_NEBULACLOUD_FALSE_ID || { echo >&2 -e "Project $WAN_NEBULACLOUD_FALSE_ID not exists...\n"; exit 1;}
    printf "Checking completed. Successfully installed gcloud.\n"
}

authorise_gcp(){
    command gcloud auth activate-service-account --key-file ${GCP_CREDENTIAL} || { echo >&2 "Failed to activate Service Account. Aborting...\n"; exit 1;}
    command gcloud config set project ${GCP_PROJECT} || { echo >&2 "Failed to set project to ${GCP_PROJECT}. Aborting...\n"; exit 1; }
    command gcloud config set compute/region ${GCP_REGION} || { echo >&2 "Failed to set compute/region to ${GCP_REGION}. Aborting...\n"; exit 1; }
    command gcloud config set compute/zone ${GCP_ZONE} || { echo >&2 "Failed to set compute/region to ${GCP_ZONE}. Aborting...\n"; exit 1; }
    gcloud config list
#     command gcloud compute set 
    
    printf "Successfully activated Service Account\n"
    printf "\nPreparing for creating a GCP Cluster\n"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
    if [ ${CONTROLLER_NODES} -gt 127 ]
    then { echo >&2 -e "Controller num overflows.\n\nController num should range 1~127"; exit 1; }
    elif [ ${WORKER_SUM_NODES} -gt 126 ]
    then { echo >&2 -e "Worker num overflows.\n\nWorker num should range 1~126"; exit 1; }
    fi
    
#     echo "!!!${WORKER_SUM_NODES}"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}

create_vpc_network(){
    printf "\nCreating custom VPC network...\n"
    command gcloud compute networks create ${VPC_NAME} --subnet-mode custom || { printf >&2 "Failed to create custom VPC network\n"; exit 1; }
    printf "Successfully create custom VPC network\n"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
    
    printf "\nCreating VPC Subnet...\n"
    command gcloud compute networks subnets create ${VPC_SUBNET_NAME} \
        --network ${VPC_NAME} \
        --range ${IP_POOL} || { printf >&2 "Failed to create Subnet\n";exit 1; }
    # command gcloud compute networks subnets create ${VPC_SUBNET_NECESSARY_NAME} \
    #     --network ${VPC_NAME} \
    #     --range ${NECESSARY_IP_POOL} || { printf >&2 "Failed to create Subnet\n";exit 1; }
    printf "Successfully create Subnet\n"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}

create_firewall_rules(){
    printf "\nCreating firewall rules...\n"
    # Internal rules
    command gcloud compute firewall-rules create ${FIREWALL_INTERNAL_NAME} \
        --allow tcp,udp,icmp \
        --network ${VPC_NAME} \
        --source-ranges ${IP_POOL},${POD_IP_POOL},${SERVICE_CLUSTER_IP_POOL} || { printf >&2 "Failed to create internal firewall rules.\n"; exit 1; }
        
    # External rules
    command gcloud compute firewall-rules create ${FIREWALL_EXTERNAL_NAME} \
        --allow tcp:22,tcp:6443,icmp \
        --network ${VPC_NAME} \
        --source-ranges 0.0.0.0/0 || { printf >&2 "Failed to create external firewall rules.\n"; exit 1; }
    printf "Successfully created firewall rules\n"
    printf "\nFirewall rules list:\n"
    gcloud compute firewall-rules list --filter="network:${VPC_NAME}"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}

create_static_ip(){
    printf "\nCreating public ip...\n"
    command gcloud compute addresses create ${VPC_NAME} \
        --region $(gcloud config get-value compute/region) || { printf >&2 "Failed to create public ip.\n"; exit 1; }
    printf "Successfully created public ip\n"
    printf "\nPublic ip lists:\n"
    gcloud compute addresses list --filter="name=('${VPC_NAME}')"
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
}

create_deploy(){
    printf "/nCreating deploy...\n"

    command gcloud compute instances create deploy \
            --async \
            --boot-disk-size 20GB \
            --can-ip-forward \
            --image-family ubuntu-1604-lts \
            --image-project ubuntu-os-cloud \
            --machine-type n1-standard-1 \
            --private-network-ip ${PREFIX3_IP_POOL}128 \
            --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
            --subnet ${VPC_SUBNET_NAME} \
            --tags ${VPC_NAME},deploy || { printf >&2 "Failed to create deploy\n"; exit 1; }
    printf "Successfully created deploy.\n"
}

create_instances(){
    printf "\nCreating controller-instances...\n"
    
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
    controller_i=0
# IP allocation-rule:   Controller_i = 10.240.0.2 ~ 10.240.0.128
#                       Worker_i = 10.240.0.129 ~ 10.240.0.254
#                       Worker_pod_i = 10.200.${Worker_i}.1 ~ 10.200.${Worker_i}.254
#                       Each worker_node contains 254 pods at most
    while(( ${controller_i} < ${CONTROLLER_NODES} ))
    do
#         echo "controller_i="${controller_i}
        ip_controller_i=`expr ${controller_i} + 2`
        command gcloud compute instances create ${CONTROLLER_NAME}${controller_i} \
            --async \
            --boot-disk-size 200GB \
            --can-ip-forward \
            --image-family ubuntu-1604-lts \
            --image-project ubuntu-os-cloud \
            --machine-type n1-standard-1 \
            --private-network-ip ${PREFIX3_IP_POOL}${ip_controller_i} \
            --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
            --subnet ${VPC_SUBNET_NAME} \
            --tags ${VPC_NAME},controller || { printf >&2 "Failed to create console_${controller_i}\n"; exit 1; }
        
# Make controller ip table
        echo ${PREFIX3_IP_POOL}${ip_controller_i} >> ${CONTROLLER_IP_TABLE}
        
# Set controller ip list
        if [ ${controller_i} -eq 0 ]
        then CONTROLLER_IP_LIST=${PREFIX3_IP_POOL}${ip_controller_i}
            echo ${CONTROLLER_IP_LIST}
        else 
            CONTROLLER_IP_LIST=${CONTROLLER_IP_LIST},${PREFIX3_IP_POOL}${ip_controller_i}
            echo ${CONTROLLER_IP_LIST}
        fi
        let "controller_i++"
    done
    printf "Successfully created controller-instances\n"
    
#     worker for gpu instances creating
    worker_gpu_i=0
    worker_i=0
    while(( ${worker_gpu_i} < ${WORKER_GPU_NODES} ))
    do
#         echo "worker_i="${WORKER_NODES}
        ip_worker_i=`expr ${worker_i} + 129`
        command gcloud compute instances create ${WORKER_GPU_NAME}${worker_i} \
            --async \
            --boot-disk-size 200GB \
            --can-ip-forward \
            --image-family ubuntu-1604-lts \
            --image-project ubuntu-os-cloud \
            --machine-type n1-standard-1 \
            --maintenance-policy TERMINATE --restart-on-failure \
            --accelerator type=nvidia-tesla-k80,count=1 \
            --metadata pod_num=${ip_worker_i},pod-cidr=${PREFIX2_POD_IP_POOL}${ip_worker_i}.0/24,startup-script='#!/bin/bash
    echo "Checking for CUDA and installing."
    # Check for CUDA and try to install.
    if ! dpkg-query -W cuda-9-0; then
      curl -O http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
      dpkg -i ./cuda-repo-ubuntu1604_9.0.176-1_amd64.deb
      sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
      apt-get update
      apt-get install cuda-9-0 -y
    fi' \
            --private-network-ip ${PREFIX3_IP_POOL}${ip_worker_i} \
            --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
            --subnet ${VPC_SUBNET_NAME} \
            --tags ${VPC_NAME},worker || { printf >&2 "Failed to create ${WORKER_GPU_NAME}${worker_i}\n"; exit 1; }
            
# Make worker ip table            
        echo ${PREFIX3_IP_POOL}${ip_worker_i} >> ${WORKER_IP_TABLE}
        
# Set worker ip list
        if [ ${worker_i} -eq 0 ]
        then WORKER_IP_LIST=${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_IP_LIST}
        else
            WORKER_IP_LIST=${WORKER_IP_LIST},${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_IP_LIST}
        fi
        
# Set worker gpu ip list
        if [ ${worker_gpu_i} -eq 0 ]
        then WORKER_GPU_IP_LIST=${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_GPU_IP_LIST}
        else
            WORKER_GPU_IP_LIST=${WORKER_GPU_IP_LIST},${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_GPU_IP_LIST}
        fi
        let "worker_i++"
        let "worker_gpu_i++"
    done
    printf "Successfully created worker-gpu-instances\n"
    
#     worker for cpu instances creating
    worker_cpu_i=0
    while(( ${worker_cpu_i} < ${WORKER_CPU_NODES} ))
    do
#         echo "worker_i="${WORKER_NODES}
        ip_worker_i=`expr ${worker_i} + 129`
        command gcloud compute instances create ${WORKER_CPU_NAME}${worker_i} \
            --async \
            --boot-disk-size 200GB \
            --can-ip-forward \
            --image-family ubuntu-1604-lts \
            --image-project ubuntu-os-cloud \
            --machine-type n1-standard-1 \
            --metadata pod_num=${ip_worker_i},pod-cidr=${PREFIX2_POD_IP_POOL}${ip_worker_i}.0/24 \
            --private-network-ip ${PREFIX3_IP_POOL}${ip_worker_i} \
            --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
            --subnet ${VPC_SUBNET_NAME} \
            --tags ${VPC_NAME},worker || { printf >&2 "Failed to create ${WORKER_CPU_NAME}${worker_i}\n"; exit 1; }
            
# Make worker ip table            
        echo ${PREFIX3_IP_POOL}${ip_worker_i} >> ${WORKER_IP_TABLE}
        
# Set worker ip list
        if [ ${worker_i} -eq 0 ]
        then WORKER_IP_LIST=${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_IP_LIST}
        else
            WORKER_IP_LIST=${WORKER_IP_LIST},${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_IP_LIST}
        fi
        
# Set worker gpu ip list
        if [ ${worker_cpu_i} -eq 0 ]
        then WORKER_CPU_IP_LIST=${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_CPU_IP_LIST}
        else
            WORKER_CPU_IP_LIST=${WORKER_CPU_IP_LIST},${PREFIX3_IP_POOL}${ip_worker_i}
            echo ${WORKER_CPU_IP_LIST}
        fi
        let "worker_i++"
        let "worker_cpu_i++"
    done
    printf "Successfully created worker-cpu-instances\n"
    
    # printf "Creating NFS server...\n"
    # gcloud compute instances create ${NFS_SERVER_NAME} \
    #         --async \
    #         --boot-disk-size 500GB \
    #         --can-ip-forward \
    #         --image-family ubuntu-1604-lts \
    #         --image-project ubuntu-os-cloud \
    #         --machine-type n1-standard-1 \
    #         --private-network-ip ${PREFIX3_NECESSARY_IP_POOL}2 \
    #         --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    #         --subnet ${VPC_SUBNET_NECESSARY_NAME} \
    #         --tags ${VPC_NAME},nfs

    # printf "Creating LDAP server...\n"
    # gcloud compute instances create ${LDAP_SERVER_NAME} \
    #         --async \
    #         --boot-disk-size 10GB \
    #         --can-ip-forward \
    #         --image-family ubuntu-1604-lts \
    #         --image-project ubuntu-os-cloud \
    #         --machine-type n1-standard-2 \
    #         --private-network-ip ${PREFIX3_NECESSARY_IP_POOL}3 \
    #         --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    #         --subnet ${VPC_SUBNET_NECESSARY_NAME} \
    #         --tags ${VPC_NAME},nfs

    printf "List instances:\n"
    gcloud compute instances list
#     read -rsp $'Press any key to continue...or Ctrl+C to exit\n' -n1 key
    
}

build_gcp_cluster(){
    create_vpc_network
    create_firewall_rules
    create_static_ip
    # create_deploy
    create_instances
}

__main__(){
    printf "\nValidating environment...\n"
    validate_environment
    
    # Authorise google cloud SDK
    printf "\nAuthorising Google Cloud Platform...\n"
    authorise_gcp
    
    printf "\nBuilding GCP Cluster...\n"
    build_gcp_cluster
    printf "Successfully create GCP Cluster\n"

}


__main__
