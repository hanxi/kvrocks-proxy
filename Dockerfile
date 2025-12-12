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
RUN mkdir -p /var/lib/kvrocks && \
    echo "bind 0.0.0.0" > /etc/kvrocks.conf && \
    echo "port 6666" >> /etc/kvrocks.conf && \
    echo "dir /var/lib/kvrocks" >> /etc/kvrocks.conf && \
    echo "requirepass \"\"" >> /etc/kvrocks.conf && \
    echo "" >> /etc/kvrocks.conf && \
    echo "################################ NAMESPACE #####################################" >> /etc/kvrocks.conf && \
    echo "# 预配置 namespace，对应 Redis 的 db0-db15" >> /etc/kvrocks.conf && \
    echo "namespace.ns0 ns0" >> /etc/kvrocks.conf && \
    echo "namespace.ns1 ns1" >> /etc/kvrocks.conf && \
    echo "namespace.ns2 ns2" >> /etc/kvrocks.conf && \
    echo "namespace.ns3 ns3" >> /etc/kvrocks.conf && \
    echo "namespace.ns4 ns4" >> /etc/kvrocks.conf && \
    echo "namespace.ns5 ns5" >> /etc/kvrocks.conf && \
    echo "namespace.ns6 ns6" >> /etc/kvrocks.conf && \
    echo "namespace.ns7 ns7" >> /etc/kvrocks.conf && \
    echo "namespace.ns8 ns8" >> /etc/kvrocks.conf && \
    echo "namespace.ns9 ns9" >> /etc/kvrocks.conf && \
    echo "namespace.ns10 ns10" >> /etc/kvrocks.conf && \
    echo "namespace.ns11 ns11" >> /etc/kvrocks.conf && \
    echo "namespace.ns12 ns12" >> /etc/kvrocks.conf && \
    echo "namespace.ns13 ns13" >> /etc/kvrocks.conf && \
    echo "namespace.ns14 ns14" >> /etc/kvrocks.conf && \
    echo "namespace.ns15 ns15" >> /etc/kvrocks.conf

# 创建启动脚本
RUN echo '#!/bin/bash' > /root/start.sh && \
    echo 'set -e' >> /root/start.sh && \
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
