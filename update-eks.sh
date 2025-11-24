#!/bin/bash
set -e

REGION="ap-southeast-1"
STACK_NAME="rtb-eks-stack"

echo "=== Updating RTB EKS Deployment ==="

# Get ECR URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rtb-server"

# Build and push new image
echo "Building and pushing new image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t rtb-server .
docker tag rtb-server:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "Image pushed: $ECR_URI:latest"

# Update deployment with correct image path
echo "Updating Kubernetes deployment..."
kubectl set image deployment/rtb-bid-service rtb-server=$ECR_URI:latest

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/rtb-bid-service

echo "Update complete!"
kubectl get pods
