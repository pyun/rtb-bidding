#!/bin/bash
set -e

export AWS_PAGER=""

# 环境准备
PREFIX="${1:-test1}"
REGION="${2:-us-east-1}"
CLUSTER_NAME="${PREFIX}-rtbfabric-cluster"
IMAGE_NAME="rtb-server"

echo "=== RTB Fabric EKS Update ==="
echo "Prefix: $PREFIX | Region: $REGION | Cluster: $CLUSTER_NAME"

# 构建并推送镜像
echo "Building and pushing image..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$IMAGE_NAME"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
docker build -t $IMAGE_NAME $SCRIPT_DIR/.. && docker tag $IMAGE_NAME:latest $ECR_URI:latest && docker push $ECR_URI:latest

# 配置 kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# 重启部署
echo "Restarting deployment..."
kubectl rollout restart deployment/rtb-bid-service

# 等待部署完成
echo "Waiting for rollout..."
kubectl rollout status deployment/rtb-bid-service

echo ""
echo "=== Update Complete ==="
echo "Check status: kubectl get pods && kubectl get svc"
