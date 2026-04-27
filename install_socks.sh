#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# --- 参数设置 ---
SOCKS_PORT=${1:-"10080"} 
INPUT_UUID=$2

FSCARMEN_CONF_DIR="/etc/sing-box/conf"
NEW_CONF_FILE="$FSCARMEN_CONF_DIR/22_socks_inbounds.json"

# --- 1. 环境检查与系统检测 ---
[[ $EUID -ne 0 ]] && echo -e "${RED}请使用 root 用户运行${PLAIN}" && exit 1

if [ -f /etc/alpine-release ]; then
    OS="alpine"
elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    OS="debian"
else
    OS="debian" # 默认尝试 Systemd 逻辑
fi

# --- 2. 准备工作 ---
mkdir -p $FSCARMEN_CONF_DIR

# --- 3. UUID 处理逻辑 ---
if [ -z "$INPUT_UUID" ]; then
    # 优先尝试使用 /proc/sys/kernel/random/uuid
    if [ -f /proc/sys/kernel/random/uuid ]; then
        MY_UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        # Alpine 可能需要安装 uuidgen
        if ! command -v uuidgen &> /dev/null; then
            [ "$OS" == "alpine" ] && apk add --no-cache util-linux
        fi
        MY_UUID=$(uuidgen)
    fi
    echo -e "${YELLOW}未指定 UUID，已生成随机 UUID: $MY_UUID${PLAIN}"
else
    MY_UUID=$INPUT_UUID
    echo -e "${GREEN}使用指定的 UUID: $MY_UUID${PLAIN}"
fi

# 提取字段：用户名(第一段)，密码(最后一段)
SOCKS_USER=$(echo $MY_UUID | cut -d '-' -f 1)
SOCKS_PASS=$(echo $MY_UUID | cut -d '-' -f 5)

# --- 4. 生成 SOCKS 配置 ---
cat <<EOF > $NEW_CONF_FILE
{
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in-233",
      "listen": "::",
      "listen_port": $SOCKS_PORT,
      "users": [
        {
          "username": "$SOCKS_USER",
          "password": "$SOCKS_PASS"
        }
      ]
    }
  ]
}
EOF

chmod 644 $NEW_CONF_FILE

# --- 5. 服务重启逻辑 (自适应) ---
echo -e "${YELLOW}正在检测 sing-box 服务并尝试重启...${PLAIN}"

restart_service() {
    if [ "$OS" == "debian" ]; then
        if systemctl is-active --quiet sing-box; then
            systemctl restart sing-box
            return 0
        fi
    elif [ "$OS" == "alpine" ]; then
        if rc-service sing-box status 2>/dev/null | grep -q "started"; then
            rc-service sing-box restart
            return 0
        fi
    fi
    return 1
}

if restart_service; then
    echo -e "--------------------------------------------------"
    echo -e "${GREEN}SOCKS 协议已注入成功！${PLAIN}"
    echo -e "系统环境: $OS"
    echo -e "监听端口: $SOCKS_PORT"
    echo -e "用户名: $SOCKS_USER"
    echo -e "密码: $SOCKS_PASS"
    echo -e "--------------------------------------------------"
else
    echo -e "${RED}错误: 未发现运行中的 sing-box 服务，配置已保存但未生效。${PLAIN}"
    echo -e "配置文件路径: $NEW_CONF_FILE"
fi
