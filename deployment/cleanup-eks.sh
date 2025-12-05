#!/bin/bash
set -e

export AWS_PAGER=""

PREFIX="${1:-test3}"
REGION="${2:-us-east-1}"
CLUSTER_NAME="${PREFIX}-rtbfabric-cluster"
STACK_NAME="${PREFIX}-rtbfabric-eks-stack"
ROLE_NAME="${PREFIX}-rtbfabric-eks-endpoint-role"
IMAGE_NAME="rtb-server"

echo "=== Cleaning up EKS resources ==="
echo "Prefix: $PREFIX | Region: $REGION | Cluster: $CLUSTER_NAME"

# 删除 K8s 资源
echo "Deleting Kubernetes resources..."
kubectl delete deployment,service --all -n default --ignore-not-found=true 2>/dev/null || true

# 删除 CloudFormation
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
echo "Waiting for stack deletion..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

# 删除 IAM 角色
echo "Deleting IAM role..."
aws iam delete-role-policy --role-name $ROLE_NAME --policy-name "${ROLE_NAME}-policy" 2>/dev/null || true
aws iam delete-role --role-name $ROLE_NAME 2>/dev/null || true

# 删除 ECR (可选)
read -p "Delete ECR repository $IMAGE_NAME? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    aws ecr delete-repository --repository-name $IMAGE_NAME --force --region $REGION 2>/dev/null || true
fi

echo ""
echo "=== Cleanup complete ==="
