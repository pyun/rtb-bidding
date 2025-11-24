#!/bin/bash
set -e

CLUSTER_NAME="rtb-cluster"
REGION="us-east-1"
STACK_NAME="rtb-eks-stack"
ECR_REPO_NAME="rtb-server"

echo "=== RTB EKS Deployment Script ==="

# 1. Create CloudFormation Stack
echo "Step 1: Creating CloudFormation stack..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://cloudformation.yaml \
  --parameters ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME \
  --capabilities CAPABILITY_IAM \
  --region $REGION

echo "Waiting for stack creation..."
aws cloudformation wait stack-create-complete \
  --stack-name $STACK_NAME \
  --region $REGION

# 2. Update kubeconfig
echo "Step 2: Updating kubeconfig..."
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $REGION

# 3. Create ECR repository
echo "Step 3: Creating ECR repository..."
aws ecr create-repository \
  --repository-name $ECR_REPO_NAME \
  --region $REGION || echo "Repository already exists"

# 4. Build and push Docker image
echo "Step 4: Building and pushing Docker image..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t $ECR_REPO_NAME .
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
docker push $ECR_URI:latest

# 5. Update k8s deployment with ECR image
echo "Step 5: Updating Kubernetes deployment..."
sed "s|<YOUR_ECR_REPO>|$ECR_URI|g" k8s-deployment.yaml > k8s-deployment-updated.yaml

# 6. Deploy to EKS
echo "Step 6: Deploying to EKS..."
kubectl apply -f k8s-deployment-updated.yaml

# 7. Get service endpoint
echo "Step 7: Waiting for LoadBalancer..."
sleep 30
kubectl get service rtb-bid-service

echo ""
echo "=== Deployment Complete ==="
echo "Get service URL with: kubectl get service rtb-bid-service"
