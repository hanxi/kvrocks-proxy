# Kvrocks Proxy

这是一个Redis协议兼容的代理，用于连接Kvrocks数据库。

## 功能特性

- 支持Redis协议
- 可通过命令行参数配置监听地址和Kvrocks服务器地址
- 支持Docker部署
- 自动化构建和推送Docker镜像

## 使用方法

### 本地运行

```bash
go run main.go -addr=:6379 -kvaddr=127.0.0.1:6666
```

或者编译后运行：

```bash
go build -o kvrocks-proxy main.go
./kvrocks-proxy -addr=:6379 -kvaddr=127.0.0.1:6666
```

### Docker运行

```bash
docker build -t kvrocks-proxy .
docker run -p 6379:6379 kvrocks-proxy
```

可以通过环境变量配置地址：

```bash
docker run -p 6379:6379 -e ADDR=:6379 -e KVADDR=127.0.0.1:6666 kvrocks-proxy
```

## 参数说明

- `-addr`：代理监听地址，默认为`:6379`
- `-kvaddr`：Kvrocks服务器地址，默认为`127.0.0.1:6666`

## GitHub Actions

项目包含自动化构建和推送Docker镜像的GitHub Actions配置：

- 当推送到`main`分支时会自动构建并推送镜像
- 当创建带有`v`前缀的标签时会构建版本化的镜像
- 支持多架构平台（amd64和arm64）

要启用自动化推送功能，需要在仓库设置中添加以下Secrets：
- `DOCKERHUB_USERNAME`：Docker Hub用户名
- `DOCKERHUB_TOKEN`：Docker Hub访问令牌