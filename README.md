# RTB Bidding System

一个简洁高效的实时竞价（RTB）系统，包含客户端和服务器端，支持多种部署方式。

## 🚀 特性

- ✅ 完整的RTB协议实现（基于OpenRTB标准）
- ✅ 高并发客户端压测工具
- ✅ 容器化部署（Docker）
- ✅ AWS Auto Scaling Group部署
- ✅ AWS EKS部署
- ✅ 无状态服务设计
- ✅ 自动扩缩容支持

## 📋 项目结构

```
rtb-project/
├── server.py                    # RTB服务器端
├── client.py                    # RTB客户端（压测工具）
├── rtb.json                     # RTB请求示例
├── requirements.txt             # Python依赖
├── Dockerfile                   # Docker镜像构建
├── cloudformation-asg.yaml      # ASG部署模板
├── cloudformation.yaml          # EKS部署模板
├── k8s-deployment.yaml          # Kubernetes部署配置
├── deploy-asg.sh               # ASG一键部署脚本
├── update-image.sh             # 镜像更新脚本
└── DEPLOYMENT.md               # 详细部署文档
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

### AWS部署

详见 [DEPLOYMENT.md](DEPLOYMENT.md)

**Auto Scaling Group（推荐）：**
```bash
chmod +x deploy-asg.sh
./deploy-asg.sh
```

**EKS部署：**
```bash
aws cloudformation create-stack \
  --stack-name rtb-eks-stack \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_IAM
```

## 📖 使用说明

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

### EKS架构
```
Internet → LoadBalancer → K8s Service → Pods → ECR
                            ↓
                    Horizontal Pod Autoscaler
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
- **云平台**: AWS (EC2, EKS, ECR, ALB, ASG)
- **IaC**: CloudFormation

## 📝 RTB协议

严格遵循OpenRTB协议格式，包含：
- Bid Request: 设备信息、用户信息、广告位信息
- Bid Response: 出价、广告创意、价格
- No-Bid Response: 拒绝竞价原因

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可

MIT License

## 👤 作者

[@pyun](https://github.com/pyun)
