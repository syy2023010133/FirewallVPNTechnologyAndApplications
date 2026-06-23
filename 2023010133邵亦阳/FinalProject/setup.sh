#!/bin/bash
set -e  # 出错立即退出

# ===================== 清理旧环境 =====================
echo "清理旧的namespace和veth接口..."
for ns in fw office guest dmz internet remote; do
    sudo ip netns del $ns 2>/dev/null || true
done

for veth in veth-fw-office veth-office veth-fw-guest veth-guest veth-fw-dmz veth-dmz veth-fw-inet veth-inet; do
    sudo ip link del $veth 2>/dev/null || true
done

# ===================== 创建namespace =====================
echo "创建namespace..."
sudo ip netns add fw
sudo ip netns add office
sudo ip netns add guest
sudo ip netns add dmz
sudo ip netns add internet
sudo ip netns add remote

# ===================== 创建veth对并配置 =====================
# 1. office <-> fw
echo "配置office网络..."
sudo ip link add veth-fw-office type veth peer name veth-office
sudo ip link set veth-fw-office netns fw
sudo ip link set veth-office netns office

sudo ip netns exec fw ip addr add 10.20.0.1/24 dev veth-fw-office
sudo ip netns exec fw ip link set veth-fw-office up
sudo ip netns exec office ip addr add 10.20.0.2/24 dev veth-office
sudo ip netns exec office ip link set veth-office up
sudo ip netns exec office ip link set lo up
sudo ip netns exec office ip route add default via 10.20.0.1

# 2. guest <-> fw
echo "配置guest网络..."
sudo ip link add veth-fw-guest type veth peer name veth-guest
sudo ip link set veth-fw-guest netns fw
sudo ip link set veth-guest netns guest

sudo ip netns exec fw ip addr add 10.30.0.1/24 dev veth-fw-guest
sudo ip netns exec fw ip link set veth-fw-guest up
sudo ip netns exec guest ip addr add 10.30.0.2/24 dev veth-guest
sudo ip netns exec guest ip link set veth-guest up
sudo ip netns exec guest ip link set lo up
sudo ip netns exec guest ip route add default via 10.30.0.1

# 3. dmz <-> fw
echo "配置dmz网络..."
sudo ip link add veth-fw-dmz type veth peer name veth-dmz
sudo ip link set veth-fw-dmz netns fw
sudo ip link set veth-dmz netns dmz

sudo ip netns exec fw ip addr add 10.40.0.1/24 dev veth-fw-dmz
sudo ip netns exec fw ip link set veth-fw-dmz up
sudo ip netns exec dmz ip addr add 10.40.0.2/24 dev veth-dmz
sudo ip netns exec dmz ip link set veth-dmz up
sudo ip netns exec dmz ip link set lo up
sudo ip netns exec dmz ip route add default via 10.40.0.1

# 4. internet <-> fw
echo "配置internet网络..."
sudo ip link add veth-fw-inet type veth peer name veth-inet
sudo ip link set veth-fw-inet netns fw
sudo ip link set veth-inet netns internet

sudo ip netns exec fw ip addr add 203.0.113.1/24 dev veth-fw-inet
sudo ip netns exec fw ip link set veth-fw-inet up
sudo ip netns exec internet ip addr add 203.0.113.10/24 dev veth-inet
sudo ip netns exec internet ip link set veth-inet up
sudo ip netns exec internet ip link set lo up
sudo ip netns exec internet ip route add default via 203.0.113.1

# ===================== 配置fw转发 =====================
echo "开启fw的IP转发..."
sudo ip netns exec fw sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo ip netns exec fw ip link set lo up

# ===================== 连通性验证 =====================
echo "验证基础连通性..."
check_ping() {
    local ns=$1
    local ip=$2
    if sudo ip netns exec $ns ping -c 2 -W 1 $ip >/dev/null; then
        echo "✅ $ns -> $ip 连通"
    else
        echo "❌ $ns -> $ip 不通"
        exit 1
    fi
}

check_ping office 10.20.0.1
check_ping guest 10.30.0.1
check_ping dmz 10.40.0.1
check_ping internet 203.0.113.1

echo "✅ 拓扑搭建完成！"