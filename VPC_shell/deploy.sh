
    command gcloud compute instances create deploy \
            --async \
            --boot-disk-size 20GB \
            --can-ip-forward \
            --image-family ubuntu-1604-lts \
            --image-project ubuntu-os-cloud \
            --machine-type n1-standard-1 \
            --private-network-ip 10.240.0.128 \
            --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
            --subnet ${VPC_SUBNET_NAME} \
            --tags ${VPC_NAME},deploy || { printf >&2 "Failed to create deploy\n"; exit 1; }