#!/bin/bash
set -e

# 生成kvrocks配置文件
KVROCKS_PASSWORD=${KVROCKS_PASSWORD:-123456}
cat > /etc/kvrocks.conf <<EOF
bind 0.0.0.0
port 6666
dir /var/lib/kvrocks
requirepass "$KVROCKS_PASSWORD"

################################ NAMESPACE #####################################
# 预配置 namespace，对应 Redis 的 db0-db15
namespace.ns0 ns0
namespace.ns1 ns1
namespace.ns2 ns2
namespace.ns3 ns3
namespace.ns4 ns4
namespace.ns5 ns5
namespace.ns6 ns6
namespace.ns7 ns7
namespace.ns8 ns8
namespace.ns9 ns9
namespace.ns10 ns10
namespace.ns11 ns11
namespace.ns12 ns12
namespace.ns13 ns13
namespace.ns14 ns14
namespace.ns15 ns15
EOF

# 启动kvrocks
kvrocks -c /etc/kvrocks.conf &
kvrocks_pid=$!
echo "kvrocks started with PID: $kvrocks_pid"

# 等待kvrocks启动
sleep 2

# 启动kvrocks-proxy
addr=${ADDR:-:6379}
kvaddr=${KVADDR:-127.0.0.1:6666}
echo "Starting kvrocks-proxy on $ADDR, connecting to kvrocks at $kvaddr"
kvrocks-proxy -addr "$addr" -kvaddr "$kvaddr" &
proxy_pid=$!
echo "kvrocks-proxy started with PID: $proxy_pid"

# 等待任一进程退出
wait -n

# 如果任一进程退出，杀死另一个进程
kill $kvrocks_pid $proxy_pid 2>/dev/null || true
exit 1
