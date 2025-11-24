# RTB 部署说明

本项目提供两种部署方式：**EKS部署** 和 **Auto Scaling Group部署**

## 方式一：Auto Scaling Group 部署（容器化，推荐）

### 架构组件
- VPC + 公有子网
- ECR容器镜像仓库
- Application Load Balancer
- Auto Scaling Group (2-10实例)
- Docker容器运行RTB服务
- 基于CPU的自动扩缩容策略

### 部署步骤

1. **一键部署（推荐）**
```bash
chmod +x deploy-asg.sh
./deploy-asg.sh
```

脚本自动完成：
- 创建CloudFormation栈和ECR仓库
- 构建并推送Docker镜像
- 启动Auto Scaling Group
- 实例自动从ECR拉取镜像并运行容器

2. **获取服务端点**
```bash
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name rtb-asg-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

echo $ALB_URL
```

3. **测试服务**
```bash
curl -X POST $ALB_URL -H 'Content-Type: application/json' -d @rtb.json
```

4. **使用客户端压测**
```bash
# 修改client.py中的SERVER_URL为ALB URL
python client.py -c 100 -d 60
```

### 更新镜像

修改代码后更新服务：
```bash
chmod +x update-image.sh
./update-image.sh
```

脚本会自动：
- 构建新镜像并推送到ECR
- 触发ASG实例刷新
- 新实例拉取最新镜像

### UserData（极简）

```bash
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker run -d -p 8080:8080 --restart always <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/rtb-server:latest
```

仅7行代码！

### Auto Scaling配置
- 最小实例数：2
- 期望实例数：3
- 最大实例数：10
- 扩缩容指标：CPU使用率 > 70%

### 清理资源
```bash
aws cloudformation delete-stack --stack-name rtb-asg-stack --region us-east-1
aws ecr delete-repository --repository-name rtb-server --force --region us-east-1
```

---

## 方式二：EKS 部署

### 架构组件
- VPC + 公有子网
- EKS Cluster (v1.31)
- EKS Node Group (1-3节点)
- ECR容器镜像仓库
- Kubernetes Deployment + LoadBalancer Service

### 部署步骤

1. **部署CloudFormation栈**
```bash
aws cloudformation create-stack \
  --stack-name rtb-eks-stack \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

2. **等待EKS集群创建（约15-20分钟）**
```bash
aws cloudformation wait stack-create-complete \
  --stack-name rtb-eks-stack \
  --region us-east-1
```

3. **配置kubectl**
```bash
aws eks update-kubeconfig \
  --name rtb-cluster \
  --region us-east-1
```

4. **创建ECR仓库并推送镜像**
```bash
# 创建ECR仓库
aws ecr create-repository \
  --repository-name rtb-server \
  --region us-east-1

# 获取账户ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/rtb-server"

# 登录ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URI

# 构建并推送镜像
docker build -t rtb-server .
docker tag rtb-server:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

5. **部署到EKS**
```bash
# 更新k8s配置中的镜像地址
sed "s|<YOUR_ECR_REPO>|$ECR_URI|g" k8s-deployment.yaml > k8s-deployment-updated.yaml

# 部署
kubectl apply -f k8s-deployment-updated.yaml

# 查看服务状态
kubectl get pods
kubectl get service rtb-bid-service
```

6. **获取服务端点**
```bash
kubectl get service rtb-bid-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 清理资源
```bash
# 删除Kubernetes资源
kubectl delete -f k8s-deployment-updated.yaml

# 删除CloudFormation栈
aws cloudformation delete-stack \
  --stack-name rtb-eks-stack \
  --region us-east-1

# 删除ECR仓库
aws ecr delete-repository \
  --repository-name rtb-server \
  --force \
  --region us-east-1
```

---

## 部署方式对比

| 特性 | Auto Scaling Group | EKS |
|------|-------------------|-----|
| 部署时间 | 5-10分钟 | 15-20分钟 |
| 复杂度 | 简单 | 中等 |
| 成本 | 较低 | 较高 |
| 容器化 | ✅ Docker | ✅ Kubernetes |
| UserData | 7行 | 不需要 |
| 适用场景 | 快速部署、中小规模 | 生产环境、大规模微服务 |

## 本地测试

```bash
# 启动服务器
python server.py

# 启动客户端（新终端）
python client.py -c 50 -d 30
```
