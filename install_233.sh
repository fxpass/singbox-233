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

# --- 核心定义：完全隔离的环境变量 ---
is_core=sb233
is_core_name=sb233
is_core_dir=/etc/sb233
is_core_bin=$is_core_dir/bin/sb233  # 二进制文件名改为 sb233
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
    echo "........... $is_core_name (Dual-Stack Coexist Mode) by $author .........."
    
    # 1. 环境清理与目录创建
    mkdir -p $is_core_dir $is_sh_dir $is_core_dir/bin $is_conf_dir $is_log_dir

    # 0. 安装必要依赖 (wget, tar, jq)
    echo -e "${yellow}检查并安装必要依赖...${none}"
    if [[ -f /usr/bin/apt ]]; then
        apt update && apt install -y wget tar jq
    elif [[ -f /sbin/apk ]]; then
        apk add wget tar jq gcompat
    elif [[ -f /usr/bin/yum ]]; then
        yum install -y wget tar jq
    fi

    # 2. 核心内核复用逻辑 (针对 NAT 小鸡已安装 fscarmen 的情况)
    # 检查 fscarmen 二进制路径
    fscarmen_bin="/etc/sing-box/sing-box"
    if [[ ! -f $fscarmen_bin ]]; then
        # 备选路径检查
        fscarmen_bin=$(which sing-box)
    fi

    if [[ ! -f $fscarmen_bin ]]; then
        echo -e "${red}错误：未发现已安装的 sing-box 内核，请先安装 fscarmen 脚本。${none}"
        exit 1
    fi

    # 建立软链接，名字必须叫 sb233 以匹配变量
    ln -sf $fscarmen_bin $is_core_bin
    echo -e "${green}已成功复用原内核：$fscarmen_bin${none}"

    # 3. 下载并解压管理脚本
    download_sh
    if [[ -f $is_sh_ok ]]; then
        tar zxf $tmpsh -C $is_sh_dir
        
        # --- 核心修正：全量源码扫描替换 ---
        # 1. 替换变量名（解决动态路径拼接问题）
        find $is_sh_dir -type f -exec sed -i "s/is_core=sing-box/is_core=sb233/g" {} +
        find $is_sh_dir -type f -exec sed -i "s/is_core_name=sing-box/is_core_name=sb233/g" {} +
        # 2. 替换硬编码路径（解决入口文件和初始化路径问题）
        find $is_sh_dir -type f -exec sed -i "s/\/etc\/sing-box/\/etc\/sb233/g" {} +
        # 3. 替换别名定义
        find $is_sh_dir -type f -exec sed -i "s/alias sb=/alias sb233=/g" {} +
        
        echo -e "${yellow}脚本内部路径与变量已修正。${none}"
    else
        echo "脚本下载失败"; exit 1
    fi

    # 4. 设置别名与软链接
    ln -sf $is_sh_dir/sing-box.sh $is_sh_bin
    # 确保别名写入 .bashrc，排除重复
    grep -q "alias sb233=" /root/.bashrc || echo "alias sb233=$is_sh_bin" >> /root/.bashrc
    chmod +x $is_sh_bin $is_core_bin

    # 5. 初始化服务 (适配新名称)
    load systemd.sh
    sed -i "s/sing-box.service/sb233.service/g" $is_sh_dir/src/systemd.sh
    sed -i "s/ExecStart=.*sing-box/ExecStart=$is_core_bin/g" $is_sh_dir/src/systemd.sh
    
    is_new_install=1
    install_service sb233 &>/dev/null

    # 6. 生成默认配置
    load core.sh
    add reality # 默认添加一个 Reality 协议，此时端口是随机的
    
    echo -e "--------------------------------------------------"
    echo -e "${green}安装完成！${none}"
    echo -e "管理命令: ${cyan}sb233${none}"
    echo -e "配置文件: ${cyan}$is_config_json${none}"
    echo -e "注意：由于是 NAT 小鸡，请立即运行 ${yellow}sb233${none} 修改端口！"
    echo -e "--------------------------------------------------"
    
    rm -rf $tmpdir
}

main $@
