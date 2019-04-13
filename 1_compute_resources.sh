#!/bin/bash
function record(){
  key=${1}
  value=${2}
  echo "export ${key}=${value}" >> resource_record.sh  
}
# create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.240.0.0/24 --output text --query 'Vpc.VpcId')
record VPC_ID ${VPC_ID}
aws ec2 create-tags --resources ${VPC_ID} --tags Key=Name,Value=kubernetes-hardway
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-support '{"Value": true}'
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-hostnames '{"Value": true}'
# create subnets
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.240.0.0/24 \
  --output text --query 'Subnet.SubnetId')
record SUBNET_ID ${SUBNET_ID}
aws ec2 create-tags --resources ${SUBNET_ID} --tags Key=Name,Value=kubernetes-hardway
# create IGW
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
record INTERNET_GATEWAY_ID ${INTERNET_GATEWAY_ID}
aws ec2 create-tags --resources ${INTERNET_GATEWAY_ID} --tags Key=Name,Value=kubernetes-hardway
aws ec2 attach-internet-gateway --internet-gateway-id ${INTERNET_GATEWAY_ID} --vpc-id ${VPC_ID}
# create Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --output text --query 'RouteTable.RouteTableId')
record ROUTE_TABLE_ID ${ROUTE_TABLE_ID}

aws ec2 create-tags --resources ${ROUTE_TABLE_ID} --tags Key=Name,Value=kubernetes-hardway
aws ec2 associate-route-table --route-table-id ${ROUTE_TABLE_ID} --subnet-id ${SUBNET_ID}
aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${INTERNET_GATEWAY_ID}
# create SG
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name kubernetes-hardway \
  --description "Kubernetes security group" \
  --vpc-id ${VPC_ID} \
  --output text --query 'GroupId')
record SECURITY_GROUP_ID ${SECURITY_GROUP_ID}
aws ec2 create-tags --resources ${SECURITY_GROUP_ID} --tags Key=Name,Value=kubernetes-hardway
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol all --cidr 10.240.0.0/24
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol all --cidr 10.200.0.0/16
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 6443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol icmp --port -1 --cidr 0.0.0.0/0
# k8s public access, network loadbalancer
LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
--name kubernetes-hardway \
--subnets ${SUBNET_ID} \
--scheme internet-facing \
--type network \
--output text --query 'LoadBalancers[].LoadBalancerArn')
record LOAD_BALANCER_ARN ${LOAD_BALANCER_ARN}
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
--name kubernetes-hardway \
--protocol TCP \
--port 6443 \
--vpc-id ${VPC_ID} \
--target-type ip \
--output text --query 'TargetGroups[].TargetGroupArn')
record TARGET_GROUP_ARN ${TARGET_GROUP_ARN}
aws elbv2 register-targets --target-group-arn ${TARGET_GROUP_ARN} --targets Id=10.240.0.1{0,1,2}
aws elbv2 create-listener \
--load-balancer-arn ${LOAD_BALANCER_ARN} \
--protocol TCP \
--port 443 \
--default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN} \
--output text --query 'Listeners[].ListenerArn'

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns ${LOAD_BALANCER_ARN} \
  --output text --query 'LoadBalancers[].DNSName')
record KUBERNETES_PUBLIC_ADDRESS ${KUBERNETES_PUBLIC_ADDRESS}

# get instance image id
IMAGE_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters \
  'Name=root-device-type,Values=ebs' \
  'Name=architecture,Values=x86_64' \
  'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*' \
  | jq -r '.Images|sort_by(.Name)[-1]|.ImageId')
record IMAGE_ID ${IMAGE_ID}
# create SSH keypair
aws ec2 create-key-pair --key-name kubernetes_hardway --output text --query 'KeyMaterial' > kubernetes_hardway.id_rsa
chmod 600 kubernetes_hardway.id_rsa

# create k8s master instances
for i in 0 1 2; do
  instance_id=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes_hardway \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type t3.micro \
    --private-ip-address 10.240.0.1${i} \
    --user-data "name=master-${i}" \
    --subnet-id ${SUBNET_ID} \
    --block-device-mappings='{"DeviceName": "/dev/sda1", "Ebs": { "VolumeSize": 50 }, "NoDevice": "" }' \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --no-source-dest-check
  aws ec2 create-tags --resources ${instance_id} --tags "Key=Name,Value=master-${i}"
  echo "master-${i} created "
done

# create k8s node instances
for i in 0 1 2; do
  instance_id=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes_hardway \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type t3.micro \
    --private-ip-address 10.240.0.2${i} \
    --user-data "name=node-${i}|pod-cidr=10.200.${i}.0/24" \
    --subnet-id ${SUBNET_ID} \
    --block-device-mappings='{"DeviceName": "/dev/sda1", "Ebs": { "VolumeSize": 50 }, "NoDevice": "" }' \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --no-source-dest-check
  aws ec2 create-tags --resources ${instance_id} --tags "Key=Name,Value=node-${i}"
  echo "node-${i} created"
done

