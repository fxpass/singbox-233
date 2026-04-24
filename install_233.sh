#!/bin/bash

author=233boy
# github=https://github.com/233boy/sing-box

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }

# root check
[[ $EUID != 0 ]] && echo -e "${red}错误!${none} 当前非 ROOT 用户." && exit 1

# --- 核心修改：定义独立变量避免冲突 ---
is_core=sb233
is_core_name=sb233
is_core_dir=/etc/sb233
is_core_bin=$is_core_dir/bin/sing-box
is_core_repo=SagerNet/sing-box
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/sb233
is_sh_bin=/usr/local/bin/sb233
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/sing-box
is_config_json=$is_core_dir/config.json
is_pkg="wget tar bash"

# tmp dir
tmpdir=$(mktemp -d)
tmpsh=$tmpdir/tmpsh
is_sh_ok=$tmpdir/is_sh_ok
is_pkg_ok=$tmpdir/is_pkg_ok

# load bash script
load() { . $is_sh_dir/src/$1; }

_wget() { wget --no-check-certificate $*; }

msg() { echo -e "${green}$(date +'%T')${none}) ${2}"; }

# download management scripts
download_sh() {
    link=https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz
    msg warn "下载管理脚本 > ${link}"
    if _wget -t 3 -q -c $link -O $tmpsh; then
        touch $is_sh_ok
    fi
}

main() {
    clear
    echo "........... $is_core_name (Shared Core Mode) by $author .........."
    echo -e "${yellow}正在安装 233boy 脚本到独立目录：$is_core_dir${none}"
    
    mkdir -p $is_core_dir $is_sh_dir $is_core_dir/bin $is_conf_dir $is_log_dir

    # 1. 检查 fscarmen 的二进制文件是否存在
    if [[ ! -f /usr/local/bin/sing-box ]]; then
        echo -e "${red}错误：未发现 fscarmen 的 sing-box 二进制文件 (/usr/local/bin/sing-box)${none}"
        exit 1
    fi

    # 2. 复用二进制文件 (软链接)
    ln -sf /usr/local/bin/sing-box $is_core_bin
    echo -e "${green}已成功复用原内核：$(/usr/local/bin/sing-box version | head -n 1)${none}"

    # 3. 下载并解压管理脚本
    download_sh
    if [[ -f $is_sh_ok ]]; then
        tar zxf $tmpsh -C $is_sh_dir
        # 关键步骤：修复脚本内部硬编码的路径
        find $is_sh_dir -type f -exec sed -i "s/\/etc\/sing-box/\/etc\/sb233/g" {} +
        find $is_sh_dir -type f -exec sed -i "s/alias sb=/alias sb233=/g" {} +
    else
        echo "脚本下载失败"; exit 1
    fi

    # 4. 设置别名与软链接
    ln -sf $is_sh_dir/sing-box.sh $is_sh_bin
    echo "alias sb233=$is_sh_bin" >> /root/.bashrc
    chmod +x $is_sh_bin $is_core_bin

    # 5. 初始化服务
    # 由于 233boy 的 systemd.sh 默认生成 sing-box.service，需要替换为 sb233.service
    load systemd.sh
    # 修改 systemd 脚本内容以适配新名称
    sed -i "s/sing-box.service/sb233.service/g" $is_sh_dir/src/systemd.sh
    sed -i "s/ExecStart=.*sing-box/ExecStart=$is_core_bin/g" $is_sh_dir/src/systemd.sh
    
    is_new_install=1
    install_service sb233 &>/dev/null

    # 6. 生成默认配置
    load core.sh
    add reality # 默认添加一个 Reality 协议
    
    echo -e "--------------------------------------------------"
    echo -e "${green}安装完成！${none}"
    echo -e "管理命令: ${cyan}sb233${none}"
    echo -e "配置文件: ${cyan}$is_config_json${none}"
    echo -e "注意：请在菜单中修改端口，确保不与原脚本及 NAT 映射冲突。"
    echo -e "--------------------------------------------------"
    
    rm -rf $tmpdir
}

main $@
