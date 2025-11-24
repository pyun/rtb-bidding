#!/bin/bash
set -e

REGION="us-east-1"
STACK_NAME="rtb-asg-stack"

echo "=== Updating RTB Docker Image ==="

# Get ECR URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rtb-server"

# Build and push new image
echo "Building and pushing new image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t rtb-server .
docker tag rtb-server:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "Image updated: $ECR_URI:latest"

# Refresh instances
echo "Refreshing Auto Scaling Group instances..."
ASG_NAME=$(aws cloudformation describe-stack-resources \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId' \
  --output text)

aws autoscaling start-instance-refresh \
  --auto-scaling-group-name $ASG_NAME \
  --region $REGION

echo "Instance refresh started. New instances will pull the updated image."
