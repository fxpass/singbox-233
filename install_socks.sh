#!/bin/bash

# --- 参数设置 ---
# 如果你想手动指定端口，可以在执行时输入，例如：bash script.sh 5555
SOCKS_PORT=${1:-"10080"} 
FSCARMEN_CONF_DIR="/etc/sing-box/conf"
NEW_CONF_FILE="$FSCARMEN_CONF_DIR/socks_233.json"

# --- 准备工作 ---
mkdir -p $FSCARMEN_CONF_DIR

# 生成 UUID
MY_UUID=$(cat /proc/sys/kernel/random/uuid)

# 提取字段：用户名(第一段)，密码(最后一段)
SOCKS_USER=$(echo $MY_UUID | cut -d '-' -f 1)
SOCKS_PASS=$(echo $MY_UUID | cut -d '-' -f 5)

# --- 生成 SOCKS 配置 ---
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

# --- 权限与服务重启 ---
chmod 644 $NEW_CONF_FILE

# 检查 fscarmen 的服务名并重启
if systemctl is-active --quiet sing-box; then
    echo -e "\033[32m正在重启 fscarmen 的 sing-box 服务以加载新协议...\033[0m"
    systemctl restart sing-box
    echo -e "--------------------------------------------------"
    echo -e "SOCKS 协议已注入成功！"
    echo -e "端口: $SOCKS_PORT"
    echo -e "用户: $SOCKS_USER"
    echo -e "密码: $SOCKS_PASS"
    echo -e "--------------------------------------------------"
else
    echo -e "\033[31m错误: 未发现运行中的 fscarmen sing-box 服务。\033[0m"
fi
