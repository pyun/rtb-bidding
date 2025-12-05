# RTB Bidding System

一个简洁高效的实时竞价（RTB）系统，包含客户端和服务器端，支持多种部署方式。

## 🚀 特性

- ✅ 完整的RTB协议实现（基于OpenRTB标准）
- ✅ 高并发客户端压测工具
- ✅ 容器化部署（Docker）
- ✅ AWS Auto Scaling Group部署
- ✅ AWS EKS Auto Mode部署
- ✅ 无状态服务设计
- ✅ 自动扩缩容支持

## 📋 项目结构

```
rtb-bidding/
├── server.py                           # RTB服务器端
├── client.py                           # RTB客户端（压测工具）
├── rtb.json                            # RTB请求示例
├── requirements.txt                    # Python依赖
├── Dockerfile                          # Docker镜像构建
└── deployment/
    ├── cloudformation-asg.yaml         # ASG部署模板
    ├── cloudformation-eks.yaml         # EKS部署模板
    ├── eks-deployment-template.yaml    # K8s部署配置
    ├── rbac-template.yaml              # K8s RBAC配置
    ├── deploy-asg.sh                   # ASG一键部署脚本
    ├── deploy-eks.sh                   # EKS一键部署脚本
    ├── cleanup-asg.sh                  # ASG清理脚本
    └── cleanup-eks.sh                  # EKS清理脚本
```

## 🏃 快速开始

### 本地运行

```bash
# 安装依赖
pip install -r requirements.txt

# 启动服务器
python server.py

# 启动客户端（新终端）
python client.py -c 10 -d 30
```

### Docker运行

```bash
# 构建镜像
docker build -t rtb-server .

# 运行容器
docker run -p 8080:8080 rtb-server
```

## 📖 AWS 部署指南

### 方式一：Auto Scaling Group 部署（推荐用于生产）

**特点：**
- 基于EC2 + Docker
- 自动扩缩容（CPU > 70%）
- Application Load Balancer
- 成本较低

**部署步骤：**

```bash
cd deployment

# 部署（默认：test, ap-southeast-1）
./deploy-asg.sh

# 自定义前缀和区域
./deploy-asg.sh prod us-east-1

# 指定EC2密钥对
./deploy-asg.sh prod us-east-1 my-key-pair
```

**清理资源：**

```bash
./cleanup-asg.sh prod us-east-1
```

**访问服务：**
```bash
# 获取Load Balancer URL
aws cloudformation describe-stacks \
  --stack-name prod-rtb-asg-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text

# 测试
curl -X POST http://<LB-URL> -H 'Content-Type: application/json' -d @rtb.json
```

### 方式二：EKS Auto Mode 部署（推荐用于Kubernetes）

**特点：**
- 完全托管的Kubernetes
- EKS Auto Mode（自动节点管理）
- Network Load Balancer
- Horizontal Pod Autoscaler
- 无需管理节点组

**部署步骤：**

```bash
cd deployment

# 部署（默认：test3, us-east-1）
./deploy-eks.sh

# 自定义前缀和区域
./deploy-eks.sh prod us-east-1
```

部署完成后会输出：
- 集群信息
- kubectl 配置命令
- create-responder-gateway 命令（用于创建RTB Fabric端点）

**检查状态：**

```bash
# 查看Pod
kubectl get pods

# 查看Service
kubectl get svc

# 查看节点
kubectl get nodes
```

**清理资源：**

```bash
./cleanup-eks.sh prod us-east-1
```

**访问服务：**
```bash
# 获取NLB地址
kubectl get svc rtb-bid-service-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 测试
curl -X POST http://<NLB-URL> -H 'Content-Type: application/json' -d @rtb.json
```

### 部署参数说明

**deploy-asg.sh:**
```bash
./deploy-asg.sh [PREFIX] [REGION] [KEY_NAME]
```
- `PREFIX`: 资源前缀（默认：test）
- `REGION`: AWS区域（默认：ap-southeast-1）
- `KEY_NAME`: EC2密钥对名称（可选）

**deploy-eks.sh:**
```bash
./deploy-eks.sh [PREFIX] [REGION]
```
- `PREFIX`: 资源前缀（默认：test3）
- `REGION`: AWS区域（默认：us-east-1）

### 重要配置

**EKS Auto Mode 要求：**
- EKS Cluster Role 需要 `sts:TagSession` 权限
- CloudFormation 模板中已包含正确配置：
```yaml
AssumeRolePolicyDocument:
  Statement:
    - Effect: Allow
      Principal:
        Service: eks.amazonaws.com
      Action: 
        - sts:AssumeRole
        - sts:TagSession
```

**自动扩缩容配置：**
- ASG: CPU > 70% 触发扩容
- EKS: HPA 基于CPU使用率（目标50%）

## 📊 使用说明

### 服务器端

服务器监听8080端口，接收POST请求到 `/bid` 端点：

- 默认70%请求返回BID
- 30%请求返回NO-BID
- 打印所有请求日志

修改 `server.py` 中的 `BID_RATE` 变量可调整比例。

### 客户端

支持高并发压测：

```bash
# 基本用法
python client.py

# 自定义并发数
python client.py -c 100

# 设置运行时长（秒）
python client.py -c 100 -d 60

# 持续运行
python client.py -c 50 -d 0
```

参数说明：
- `-c, --concurrency`: 并发请求数（默认10）
- `-d, --duration`: 持续时间秒数，0表示持续运行（默认0）

## 🏗️ 架构

### Auto Scaling Group架构
```
Internet → ALB → ASG (EC2 + Docker) → ECR
                  ↓
            Auto Scaling (CPU > 70%)
```

### EKS Auto Mode架构
```
Internet → NLB → K8s Service → Pods → ECR
                  ↓                ↓
            Auto Scaling    HPA (CPU > 50%)
            (Managed Nodes)
```

## 📊 性能

- 单实例QPS: ~1000
- 支持水平扩展
- 自动扩缩容
- 无状态设计

## 🛠️ 技术栈

- **语言**: Python 3.11
- **框架**: Flask
- **容器**: Docker
- **云平台**: AWS (EC2, EKS, ECR, ALB, NLB, ASG)
- **IaC**: CloudFormation
- **编排**: Kubernetes (EKS Auto Mode)

## 📝 RTB协议

严格遵循OpenRTB协议格式，包含：
- Bid Request: 设备信息、用户信息、广告位信息
- Bid Response: 出价、广告创意、价格
- No-Bid Response: 拒绝竞价原因

## 🔧 故障排查

### EKS Pod 无法启动

**问题：** Pod 处于 Pending 状态，提示 "no nodes available"

**原因：** EKS Auto Mode 需要正确的 IAM 权限

**解决：** 确保 EKS Cluster Role 包含 `sts:TagSession` 权限（已在 cloudformation-eks.yaml 中配置）

### 连接私有子网实例

**方法1：** 使用 kubectl debug
```bash
kubectl debug node/<node-name> -it --image=ubuntu
```

**方法2：** 配置 SSM VPC 端点后使用 Session Manager

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可

MIT License
