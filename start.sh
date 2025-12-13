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
namespace.db0 0
namespace.db1 1
namespace.db2 2
namespace.db3 3
namespace.db4 4
namespace.db5 5
namespace.db6 6
namespace.db7 7
namespace.db8 8
namespace.db9 9
namespace.db10 10
namespace.db11 11
namespace.db12 12
namespace.db13 13
namespace.db14 14
namespace.db15 15
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
