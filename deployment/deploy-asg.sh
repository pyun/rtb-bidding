#!/bin/bash
set -e

export AWS_PAGER=""

# 环境准备
PREFIX="${1:-test1}"
REGION="${2:-us-east-1}"
STACK_NAME="${PREFIX}-rtbfabric-asg-stack"
TAG_VALUE="${PREFIX}-rtbfabric-asg"
IMAGE_NAME="rtb-server"
KEY_NAME="${3:-}"  # Optional: EC2 key pair name

echo "=== RTB Auto Scaling Group Deployment ==="
echo "Prefix: $PREFIX | Region: $REGION | Stack: $STACK_NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 构建并推送镜像
echo "Building and pushing image..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$IMAGE_NAME"

aws ecr describe-repositories --repository-names $IMAGE_NAME --region $REGION &> /dev/null || \
    aws ecr create-repository --repository-name $IMAGE_NAME --region $REGION --tags Key=usage,Value=$TAG_VALUE

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
docker build -t $IMAGE_NAME $SCRIPT_DIR/.. && docker tag $IMAGE_NAME:latest $ECR_URI:latest && docker push $ECR_URI:latest

# 部署 CloudFormation
echo "Deploying CloudFormation stack..."
if [ -z "$KEY_NAME" ]; then
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$SCRIPT_DIR/cloudformation-asg.yaml \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --tags Key=usage,Value=$TAG_VALUE
else
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$SCRIPT_DIR/cloudformation-asg.yaml \
    --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --tags Key=usage,Value=$TAG_VALUE
fi

echo "Waiting for stack creation (5-10 minutes)..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

LB_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' --output text)

echo ""
echo "=== Deployment Complete ==="
echo "Stack: $STACK_NAME"
echo "Load Balancer URL: $LB_URL"
echo "ECR Repository: $ECR_URI"
echo ""
echo "Test: curl -X POST $LB_URL -H 'Content-Type: application/json' -d @rtb.json"
