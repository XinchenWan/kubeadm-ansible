#!/bin/bash

CA_DIRECTORY=CA_Registry
KUBECONFIG_DIRECTORY=Kubeconfig_Registry
ENCRYPT_DIRECTORY=Encrypt_yaml
CONTROLLER_IP_TABLE=controller_ip_table.txt
WORKER_IP_TABLE=worker_ip_table.txt
WORKER_POD_IP_TABLE=worker_pod_ip_table.txt

WORKER_GPU_NAME=worker-gpu
WORKER_CPU_NAME=worker-cpu
# SSH_SHELLFILE_DIRECTORY=ssh_shellfile_Registry

delete_instances(){
    printf "Deleting compute instances...\n"
    gcloud -q compute instances delete \
       deploy \
       controller-0 controller-1 controller-2 controller-3 \
        ${WORKER_GPU_NAME}-0 ${WORKER_GPU_NAME}-1 ${WORKER_GPU_NAME}-2 \
        ${WORKER_CPU_NAME}-0 ${WORKER_CPU_NAME}-1 ${WORKER_CPU_NAME}-2 ${WORKER_CPU_NAME}-3 ${WORKER_CPU_NAME}-4 ${WORKER_CPU_NAME}-5 ${WORKER_CPU_NAME}-6
    printf "Successfully deleted compute instances\n"
}

delete_exload_balancer(){
    printf "Deleting external load balancer network resources...\n"
    gcloud -q compute forwarding-rules delete kubernetes-forwarding-rule \
        --region $(gcloud config get-value compute/region)
    gcloud -q compute target-pools delete kubernetes-target-pool
    printf "Successfully delete external load balancer network resources\n"
}

delete_static_IP(){
    printf "Deleting static IP address...\n"
    gcloud -q compute addresses delete kubernetes-the-hard-way
    printf "Successfully delete static IP address\n"
}

delete_firewall_rules(){
    printf "Deleting firewall rules...\n"
    gcloud -q compute firewall-rules delete \
        kubernetes-the-hard-way-allow-nginx-service \
        kubernetes-the-hard-way-allow-internal \
        kubernetes-the-hard-way-allow-external
    printf "Successfully delete firewall rules\n"
}

delete_pod_routes(){
    printf "Deleting pod routes...\n"
    gcloud -q compute routes delete \
        kubernetes-route-10-200-129-0-24 \
        kubernetes-route-10-200-130-0-24 \
        kubernetes-route-10-200-131-0-24 \
        kubernetes-route-10-200-132-0-24 \
        kubernetes-route-10-200-133-0-24 \
        kubernetes-route-10-200-134-0-24 \
        kubernetes-route-10-200-135-0-24 \
        kubernetes-route-10-200-136-0-24
    printf "Successfully delete pod network routes\n"
}

delete_subnet(){
    printf "Deleting subnet...\n"
    gcloud -q compute networks subnets delete kubernetes
    printf "Successfully delete subnet\n"
}

delete_network_VPC(){
    printf "Deleting network...\n"
    gcloud -q compute networks delete kubernetes-the-hard-way
    printf "Successfully delete VPC\n"
}

delete_directory(){
    rm -r ${CA_DIRECTORY}
    rm -r ${KUBECONFIG_DIRECTORY}
    rm -r ${ENCRYPT_DIRECTORY}
#     rm -r ${SSH_SHELLFILE_DIRECTORY}
}

delete_file(){
    rm ${CONTROLLER_IP_TABLE}
    rm ${WORKER_IP_TABLE}
    rm ${WORKER_POD_IP_TABLE}
}

__main__(){
    delete_instances
    delete_exload_balancer
    delete_static_IP
    delete_firewall_rules
    delete_pod_routes
    delete_subnet
    delete_network_VPC
    delete_directory
    delete_file
}


__main__
