#!/bin/bash
set -e

export AWS_PAGER=""

PREFIX="${1:-test}"
REGION="${2:-ap-southeast-1}"
STACK_NAME="${PREFIX}-rtb-asg-stack"
IMAGE_NAME="rtb-server"

echo "=== Cleaning up ASG resources ==="
echo "Prefix: $PREFIX | Region: $REGION | Stack: $STACK_NAME"

# 删除 CloudFormation
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
echo "Waiting for stack deletion..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

# 删除 ECR (可选)
read -p "Delete ECR repository $IMAGE_NAME? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    aws ecr delete-repository --repository-name $IMAGE_NAME --force --region $REGION 2>/dev/null || true
fi

echo ""
echo "=== Cleanup complete ==="
