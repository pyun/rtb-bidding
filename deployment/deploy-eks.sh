#!/bin/bash
set -e

export AWS_PAGER=""

# 环境准备
PREFIX="${1:-test1}"
REGION="${2:-us-east-1}"
CLUSTER_NAME="${PREFIX}-rtbfabric-cluster"
STACK_NAME="${PREFIX}-rtbfabric-eks-stack"
TAG_VALUE="${PREFIX}-rtbfabric-eks"
EKS_VERSION="1.33"
KUBECTL_VERSION="1.33.0"
IMAGE_NAME="rtb-server"
ROLE_NAME="${PREFIX}-rtbfabric-eks-endpoint-role"

echo "=== RTB Fabric EKS Deployment ==="
echo "Prefix: $PREFIX | Region: $REGION | Cluster: $CLUSTER_NAME"

# 检查 AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
fi

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -sLO "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    chmod +x kubectl && sudo mv kubectl /usr/local/bin/
fi

# 构建并推送镜像
echo "Building and pushing image..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$IMAGE_NAME"

aws ecr describe-repositories --repository-names $IMAGE_NAME --region $REGION &> /dev/null || \
    aws ecr create-repository --repository-name $IMAGE_NAME --region $REGION --tags Key=usage,Value=$TAG_VALUE

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
docker build -t $IMAGE_NAME $SCRIPT_DIR/.. && docker tag $IMAGE_NAME:latest $ECR_URI:latest && docker push $ECR_URI:latest

# 创建 IAM 角色
echo "Creating IAM role..."
if ! aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
    aws iam create-role --role-name $ROLE_NAME --tags Key=usage,Value=$TAG_VALUE Key=RTBFabricManagedEndpoint,Value=true \
        --assume-role-policy-document '{
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": ["rtbfabric.amazonaws.com", "rtbfabric-endpoints.amazonaws.com"]},
            "Action": "sts:AssumeRole"
          }]
        }'
    
    aws iam put-role-policy --role-name $ROLE_NAME --policy-name "${ROLE_NAME}-policy" \
        --policy-document "{
          \"Version\": \"2012-10-17\",
          \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Action\": [
              \"autoscaling:DescribeAutoScalingGroups\",
              \"ec2:DescribeInstanceStatus\",
              \"ec2:DescribeInstances\",
              \"ec2:DescribeAvailabilityZones\"
            ],
            \"Resource\": \"*\",
            \"Condition\": {\"StringEquals\": {\"ec2:Region\": \"$REGION\"}}
          }]
        }"
fi
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

# 部署 CloudFormation
echo "Deploying CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$SCRIPT_DIR/cloudformation-eks.yaml \
    --parameters ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME \
                 ParameterKey=TagValue,ParameterValue=$TAG_VALUE \
                 ParameterKey=EKSVersion,ParameterValue=$EKS_VERSION \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --tags Key=usage,Value=$TAG_VALUE

echo "Waiting for stack creation (15-20 minutes)..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

CLUSTER_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterRoleArn`].OutputValue' --output text)
NODE_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`NodeRoleArn`].OutputValue' --output text)

# 配置 kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# 配置 IAM Access Entries
echo "Configuring IAM access entries..."
CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $ROLE_ARN --region $REGION || true
aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $ROLE_ARN \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster --region $REGION || true

aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $CURRENT_USER_ARN --region $REGION || true
aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $CURRENT_USER_ARN \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster --region $REGION || true

aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $CLUSTER_ROLE_ARN --region $REGION || true
aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $CLUSTER_ROLE_ARN \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster --region $REGION || true

aws eks create-access-entry --cluster-name $CLUSTER_NAME --principal-arn $NODE_ROLE_ARN --region $REGION || true
aws eks associate-access-policy --cluster-name $CLUSTER_NAME --principal-arn $NODE_ROLE_ARN \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope type=cluster --region $REGION || true

# 应用 RBAC
echo "Applying RBAC..."
sed "s|ROLE_ARN_PLACEHOLDER|$ROLE_ARN|g" $SCRIPT_DIR/rbac-template.yaml | kubectl apply -f -

# 部署服务
echo "Deploying service..."
sed "s|IMAGE_URI_PLACEHOLDER|$ECR_URI:latest|g" $SCRIPT_DIR/eks-deployment-template.yaml | kubectl apply -f -

echo ""
echo "=== Deployment Complete ==="
echo "Cluster: $CLUSTER_NAME"
echo "Check status: kubectl get pods && kubectl get svc"

# 获取集群信息
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)
CLUSTER_CA=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.certificateAuthority.data' --output text)
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNET_IDS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ' ')
SG_ID1=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.securityGroupIds[0]' --output text)
SG_ID2=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

echo ""
echo "=== Create Responder Gateway Command ==="
echo "aws rtbfabric create-responder-gateway \\"
echo "--vpc-id $VPC_ID \\"
echo "--subnet-ids $SUBNET_IDS \\"
echo "--security-group-ids $SG_ID1 $SG_ID2 \\"
echo "--port 8080 \\"
echo "--protocol HTTP \\"
echo "--managed-endpoint-configuration '{"
echo "\"eksEndpoints\": {"
echo "  \"endpointsResourceName\": \"rtb-bid-service\","
echo "  \"endpointsResourceNamespace\": \"default\","
echo "  \"clusterApiServerEndpointUri\": \"$CLUSTER_ENDPOINT\","
echo "  \"clusterApiServerCaCertificateChain\": \"$CLUSTER_CA\","
echo "  \"clusterName\": \"$CLUSTER_NAME\","
echo "  \"roleArn\": \"$ROLE_ARN\""
echo "}"
echo "}' \\"
echo "--region $REGION \\"
echo "--description \"$PREFIX rtbfabric eks endpoint\""
