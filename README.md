# Kvrocks Proxy

一个轻量级的 Redis 协议代理，用于桥接 Redis 客户端和 Kvrocks 数据库。

## 核心功能

- **Redis 协议兼容**：完全支持 Redis 协议，可使用任何 Redis 客户端连接
- **SELECT 命令转换**：自动将 Redis 的 `SELECT db` 命令转换为 Kvrocks 的 `AUTH nsdb` 命令，实现数据库切换
- **命令透明转发**：其他 Redis 命令直接转发到 Kvrocks 服务器
- **连接管理**：为每个客户端连接维护独立的 Kvrocks 连接
- **Docker 支持**：提供 Docker 镜像和多架构支持（amd64/arm64）
- **CI/CD 集成**：通过 GitHub Actions 自动构建和发布

## 快速开始

### 前置要求

- Go 1.21 或更高版本（本地编译）
- 运行中的 Kvrocks 服务器
- Docker（可选，用于容器化部署）

### 本地运行

直接运行：

```bash
go run main.go -addr=:6379 -kvaddr=127.0.0.1:6666
```

或者编译后运行：

```bash
go build -o kvrocks-proxy main.go
./kvrocks-proxy -addr=:6379 -kvaddr=127.0.0.1:6666
```

### 使用示例

启动代理后，可以使用任何 Redis 客户端连接：

```bash
# 使用 redis-cli 连接
redis-cli -p 6379

# 切换数据库（会自动转换为 Kvrocks 的 namespace）
SELECT 1  # 等同于 Kvrocks 的 AUTH ns1

# 执行其他 Redis 命令
SET key value
GET key
```

### Docker 部署

构建镜像：

```bash
docker build -t kvrocks-proxy .
```

运行容器：

```bash
# 基本运行
docker run -p 6379:6379 kvrocks-proxy

# 自定义配置
docker run -p 6379:6379 \
  -e ADDR=:6379 \
  -e KVADDR=your-kvrocks-host:6666 \
  kvrocks-proxy

# 使用 Docker Compose
docker-compose up -d
```

## 配置参数

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| `-addr` | `ADDR` | `:6379` | 代理服务监听地址 |
| `-kvaddr` | `KVADDR` | `127.0.0.1:6666` | Kvrocks 服务器地址 |

## 工作原理

1. **连接管理**：为每个 Redis 客户端连接创建独立的 Kvrocks 连接
2. **命令转换**：
   - `SELECT db` → `AUTH nsdb`（将数据库编号转换为 Kvrocks namespace）
   - 其他命令直接透传到 Kvrocks
3. **响应处理**：将 Kvrocks 的响应转换为 Redis 协议格式返回给客户端

## CI/CD

项目使用 GitHub Actions 实现自动化构建和发布：

### 自动构建触发条件

- **推送到 main 分支**：自动构建并推送 `latest` 标签镜像
- **创建版本标签**：推送 `v*` 格式的标签（如 `v1.0.0`）时，构建对应版本的镜像

### 多架构支持

支持以下平台架构：
- `linux/amd64`
- `linux/arm64`

### 配置 Secrets

要启用自动推送到 Docker Hub，需在 GitHub 仓库设置中添加以下 Secrets：

| Secret 名称 | 说明 |
|------------|------|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub 访问令牌（[创建方法](https://docs.docker.com/docker-hub/access-tokens/)）|

## 技术栈

- **Go**：使用 Go 语言开发
- **redcon**：Redis 协议服务器实现
- **go-redis**：Redis 客户端库
- **Docker**：容器化部署
- **GitHub Actions**：CI/CD 自动化

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件