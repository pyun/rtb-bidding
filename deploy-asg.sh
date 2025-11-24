#!/bin/bash
set -e

STACK_NAME="rtb-asg-stack"
REGION="us-east-1"
KEY_NAME=""  # Optional: Set your EC2 key pair name

echo "=== RTB Auto Scaling Group Deployment (Containerized) ==="

# Step 1: Deploy CloudFormation stack (creates ECR repo)
echo "Step 1: Deploying CloudFormation stack..."
if [ -z "$KEY_NAME" ]; then
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://cloudformation-asg.yaml \
    --capabilities CAPABILITY_IAM \
    --region $REGION
else
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://cloudformation-asg.yaml \
    --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION
fi

echo "Waiting for ECR repository creation..."
sleep 30

# Step 2: Build and push Docker image
echo "Step 2: Building and pushing Docker image..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rtb-server"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t rtb-server .
docker tag rtb-server:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "Image pushed to: $ECR_URI:latest"

# Step 3: Wait for stack completion
echo "Step 3: Waiting for stack creation (this may take 5-10 minutes)..."
aws cloudformation wait stack-create-complete \
  --stack-name $STACK_NAME \
  --region $REGION

# Get Load Balancer URL
echo ""
echo "=== Deployment Complete ==="
LB_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

echo "RTB Bid Service URL: $LB_URL"
echo "ECR Repository: $ECR_URI"
echo ""
echo "Test with: curl -X POST $LB_URL -H 'Content-Type: application/json' -d @rtb.json"
