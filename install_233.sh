#!/bin/bash
# 233boy sing-box 并存版一键安装脚本 (修复版)

# 定义变量
is_core=sing-box-233
is_core_dir=/etc/$is_core
is_sh_dir=$is_core_dir/sh
is_core_bin=$is_core_dir/bin/$is_core

# 0. 基础环境清理与依赖安装
apt update && apt install -y jq curl wget tar || yum install -y jq curl wget tar

# 1. 下载原始脚本 (这里演示通过 github 仓库获取)
# 假设你已经准备好了原始脚本压缩包
# 如果是直接通过 git 克隆或下载，请确保下载路径正确
mkdir -p $is_core_dir
# 这里为了保证逻辑，请确保你有一个正确的 code.tar.gz 来源
# 或者使用 wget 下载原始 233boy 的脚本
wget -qO- https://github.com/233boy/sing-box/releases/latest/download/code.tar.gz | tar zxf - -C $is_core_dir

# 2. 【核心修复】全局变量强力替换
# 这是解决你之前所有报错的关键步骤
# 将脚本中所有的 sing-box 替换为 sing-box-233，确保它不会去找 fscarman 的路径
find $is_core_dir/sh/ -type f -exec sed -i 's/sing-box/sing-box-233/g' {} +
# 修正因为替换导致部分目录路径冗余的问题
find $is_core_dir/sh/ -type f -exec sed -i 's|/etc/sing-box-233-233|/etc/sing-box-233|g' {} +

# 3. 下载二进制内核
# 自动识别架构并下载
arch=$(uname -m)
[[ $arch == "x86_64" ]] && arch=amd64
[[ $arch == "aarch64" ]] && arch=arm64
latest_ver=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep tag_name | cut -d '"' -f 4)
mkdir -p $is_core_dir/bin
wget -O $is_core_bin.tar.gz "https://github.com/SagerNet/sing-box/releases/download/${latest_ver}/sing-box-${latest_ver:1}-linux-${arch}.tar.gz"
tar zxf $is_core_bin.tar.gz --strip-components 1 -C $is_core_dir/bin
mv $is_core_dir/bin/sing-box $is_core_bin
chmod +x $is_core_bin

# 4. 创建别名与软链接
ln -sf $is_core_dir/sh/sing-box.sh /usr/local/bin/sb233
echo "alias sb233='/usr/local/bin/sb233'" >> /root/.bashrc

# 5. 生成对应的 systemd 服务
cat > /etc/systemd/system/$is_core.service <<EOF
[Unit]
Description=sing-box service (233boy instance)
After=network.target

[Service]
ExecStart=$is_core_bin run -c $is_core_dir/config.json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $is_core

echo "安装完成！请执行 source /root/.bashrc 后输入 sb233 使用。"
