#!/bin/bash
set -e

REGION="ap-southeast-1"
STACK_NAME="rtb-eks-stack"
CLUSTER_NAME="rtb-cluster"

echo "=== Deploying RTB to EKS ==="

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/rtb-server"

# Create ECR repository if not exists
echo "Creating ECR repository..."
aws ecr describe-repositories --repository-names rtb-server --region $REGION 2>/dev/null || \
  aws ecr create-repository --repository-name rtb-server --region $REGION

# Build and push Docker image
echo "Building and pushing Docker image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t rtb-server .
docker tag rtb-server:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "Image pushed: $ECR_URI:latest"

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_IAM \
  --region $REGION

echo "Waiting for stack creation..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Update k8s deployment with ECR URI
echo "Updating k8s deployment file..."
sed "s|<YOUR_ECR_REPO>|$ECR_URI|g" k8s-deployment.yaml > k8s-deployment-updated.yaml

# Deploy to Kubernetes
echo "Deploying to Kubernetes..."
kubectl apply -f k8s-deployment-updated.yaml

echo "Waiting for deployment..."
kubectl rollout status deployment/rtb-bid-service

# Get service endpoint
echo ""
echo "=== Deployment Complete ==="
kubectl get service rtb-bid-service
echo ""
echo "Get LoadBalancer URL with:"
echo "kubectl get service rtb-bid-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
