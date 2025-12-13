FROM golang AS builder

WORKDIR /app

# 复制go mod和sum文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN go build -o kvrocks-proxy .

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libssl3 \
    libatomic1 \
    libgcc-s1 \
    ca-certificates \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

# 从builder阶段复制预构建的二进制文件
COPY --from=builder /app/kvrocks-proxy /bin/kvrocks-proxy
COPY --from=apache/kvrocks /bin/kvrocks /bin/kvrocks

# 创建kvrocks配置文件
RUN mkdir -p /var/lib/kvrocks

# 复制启动脚本
COPY start.sh /root/start.sh
RUN chmod +x /root/start.sh

# 暴露端口
EXPOSE 6379 6666

# 运行启动脚本
CMD ["/root/start.sh"]
