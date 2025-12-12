FROM golang AS builder

WORKDIR /app

# 复制go mod和sum文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN go build -o kvrocks-proxy .

# 使用alpine镜像作为运行环境
FROM --platform=$TARGETPLATFORM alpine:3.19

RUN apk add --no-cache ca-certificates bash
WORKDIR /root/

# 从builder阶段复制预构建的二进制文件
COPY --from=builder /app/kvrocks-proxy /bin/
COPY --from=apache/kvrocks /bin/kvrocks /bin/

# 创建kvrocks配置文件
RUN mkdir -p /var/lib/kvrocks

# 创建启动脚本（需要在原有启动脚本之前添加配置文件生成逻辑）
RUN echo '#!/bin/bash' > /root/start.sh && \
    echo 'set -e' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 生成kvrocks配置文件' >> /root/start.sh && \
    echo 'KVROCKS_PASSWORD=${KVROCKS_PASSWORD:-}' >> /root/start.sh && \
    echo 'cat > /etc/kvrocks.conf <<EOF' >> /root/start.sh && \
    echo 'bind 0.0.0.0' >> /root/start.sh && \
    echo 'port 6666' >> /root/start.sh && \
    echo 'dir /var/lib/kvrocks' >> /root/start.sh && \
    echo 'requirepass "$KVROCKS_PASSWORD"' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '################################ NAMESPACE #####################################' >> /root/start.sh && \
    echo '# 预配置 namespace，对应 Redis 的 db0-db15' >> /root/start.sh && \
    echo 'namespace.ns0 ns0' >> /root/start.sh && \
    echo 'namespace.ns1 ns1' >> /root/start.sh && \
    echo 'namespace.ns2 ns2' >> /root/start.sh && \
    echo 'namespace.ns3 ns3' >> /root/start.sh && \
    echo 'namespace.ns4 ns4' >> /root/start.sh && \
    echo 'namespace.ns5 ns5' >> /root/start.sh && \
    echo 'namespace.ns6 ns6' >> /root/start.sh && \
    echo 'namespace.ns7 ns7' >> /root/start.sh && \
    echo 'namespace.ns8 ns8' >> /root/start.sh && \
    echo 'namespace.ns9 ns9' >> /root/start.sh && \
    echo 'namespace.ns10 ns10' >> /root/start.sh && \
    echo 'namespace.ns11 ns11' >> /root/start.sh && \
    echo 'namespace.ns12 ns12' >> /root/start.sh && \
    echo 'namespace.ns13 ns13' >> /root/start.sh && \
    echo 'namespace.ns14 ns14' >> /root/start.sh && \
    echo 'namespace.ns15 ns15' >> /root/start.sh && \
    echo 'EOF' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 启动kvrocks' >> /root/start.sh && \
    echo 'kvrocks -c /etc/kvrocks.conf &' >> /root/start.sh && \
    echo 'KVROCKS_PID=$!' >> /root/start.sh && \
    echo 'echo "kvrocks started with PID: $KVROCKS_PID"' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 等待kvrocks启动' >> /root/start.sh && \
    echo 'sleep 2' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 启动kvrocks-proxy' >> /root/start.sh && \
    echo 'ADDR=${ADDR:-:6379}' >> /root/start.sh && \
    echo 'KVADDR=${KVADDR:-127.0.0.1:6666}' >> /root/start.sh && \
    echo 'echo "Starting kvrocks-proxy on $ADDR, connecting to kvrocks at $KVADDR"' >> /root/start.sh && \
    echo 'kvrocks-proxy -addr "$ADDR" -kvaddr "$KVADDR" &' >> /root/start.sh && \
    echo 'PROXY_PID=$!' >> /root/start.sh && \
    echo 'echo "kvrocks-proxy started with PID: $PROXY_PID"' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 等待任一进程退出' >> /root/start.sh && \
    echo 'wait -n' >> /root/start.sh && \
    echo '' >> /root/start.sh && \
    echo '# 如果任一进程退出，杀死另一个进程' >> /root/start.sh && \
    echo 'kill $KVROCKS_PID $PROXY_PID 2>/dev/null || true' >> /root/start.sh && \
    echo 'exit 1' >> /root/start.sh && \
    chmod +x /root/start.sh

# 暴露端口
EXPOSE 6379 6666

# 运行启动脚本
CMD ["/root/start.sh"]