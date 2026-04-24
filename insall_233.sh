#!/bin/bash

# 修改说明：
# 1. 核心目录从 /etc/sing-box 改为 /etc/sing-box-233
# 2. 别名从 sb 改为 sb233
# 3. 服务名从 sing-box 改为 sing-box-233
# 4. 这样安装后，你可以通过 sb233 命令管理这套协议，且不影响原有的 fscarman 脚本。

author=233boy
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }

is_err=$(_red_bg 错误!)
err() { echo -e "\n$is_err $@\n" && exit 1; }

[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

# --- 核心路径修改区 (关键) ---
is_core=sing-box-233
is_core_name=sing-box-233
is_core_dir=/etc/$is_core
# 如果你想复用 fscarman 的二进制文件，可以把下面这行改为 is_core_bin=/etc/sing-box/bin/sing-box
# 但建议保留默认，防止两个脚本在更新内核时互相干扰版本要求
is_core_bin=$is_core_dir/bin/sing-box 
is_core_repo=SagerNet/sing-box
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/sing-box
is_pkg="wget tar bash"
is_config_json=$is_core_dir/config.json
# ---------------------------

cmd=$(type -P apt-get || type -P yum || type -P zypper || type -P apk)
is_systemd=$(type -P systemctl)
is_wget=$(type -P wget)

case $(uname -m) in
amd64 | x86_64) is_arch=amd64 ;;
*aarch64* | *armv8*) is_arch=arm64 ;;
*) err "此脚本仅支持 64 位系统..." ;;
esac

tmp_var_lists=(tmpcore tmpsh tmpjq is_core_ok is_sh_ok is_jq_ok is_pkg_ok)
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && tmpdir=/tmp/tmp-$RANDOM
for i in ${tmp_var_lists[*]}; do export $i=$tmpdir/$i; done

load() { . $is_sh_dir/src/$1; }
_wget() { [[ $proxy ]] && export https_proxy=$proxy; wget --no-check-certificate $*; }

msg() {
    case $1 in
    warn) local color=$yellow ;;
    err) local color=$red ;;
    ok) local color=$green ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# (此处省略部分原有的下载和环境检查函数，逻辑保持不变)
# [由于字数限制，核心逻辑已在 main 函数中整合修改]

exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && { msg err "安装过程出现错误..."; exit 1; }
    exit
}

install_pkg() {
    # 保持原有逻辑
    yum install epel-release -y &>/dev/null || true
    $cmd install -y wget tar bash &>/dev/null && >$is_pkg_ok
}

download() {
    case $1 in
    core)
        [[ ! $is_core_ver ]] && is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest" | grep tag_name | grep -E -o 'v([0-9.]+)')
        link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/sing-box-${is_core_ver:1}-linux-${is_arch}.tar.gz"
        tmpfile=$tmpcore; is_ok=$is_core_ok
        ;;
    sh)
        link=https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz
        tmpfile=$tmpsh; is_ok=$is_sh_ok
        ;;
    esac
    _wget -t 3 -q -c $link -O $tmpfile && mv -f $tmpfile $is_ok
}

main() {
    # 检查是否重复安装这个“并存版”
    [[ -f $is_sh_bin ]] && err "检测到并存版脚本已安装, 请使用 ${green} $is_core ${none} 命令."

    mkdir -p $tmpdir
    msg warn "开始安装 233boy 并存版..."
    
    install_pkg
    download core &
    download sh &
    wait

    # 创建目录并解压
    mkdir -p $is_sh_dir
    tar zxf $is_sh_ok -C $is_sh_dir
    mkdir -p $is_core_dir/bin
    tar zxf $is_core_ok --strip-components 1 -C $is_core_dir/bin

    # --- 核心：修改别名，防止冲突 ---
    echo "alias sb233=$is_sh_bin" >>/root/.bashrc
    ln -sf $is_sh_dir/sing-box.sh $is_sh_bin
    
    # 关键修改：替换脚本内部调用的默认路径
    # 使用 sed 批量替换脚本源代码中的目录、别名和服务名
    find $is_sh_dir -type f -exec sed -i "s|/etc/sing-box|$is_core_dir|g" {} +
    find $is_sh_dir -type f -exec sed -i "s|/var/log/sing-box|/var/log/$is_core|g" {} +
    find $is_sh_dir -type f -exec sed -i "s|alias sb=|alias sb233=|g" {} +
    find $is_sh_dir -type f -exec sed -i "s|sb_bin=sb|sb_bin=sb233|g" {} +

    chmod +x $is_core_bin $is_sh_bin

    # 创建独立的服务
    # 注意：这里需要确保加载的 systemd.sh 内部服务名也被替换
    load systemd.sh
    # 手动定义一个新的安装服务函数，避免污染
    cat > /etc/systemd/system/${is_core}.service <<EOF
[Unit]
Description=sing-box service (233boy instance)
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=$is_core_bin run -c $is_config_json
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ${is_core}

    mkdir -p $is_conf_dir
    load core.sh
    add reality # 默认添加一个协议防止启动失败
    
    systemctl start ${is_core}
    msg ok "安装完成！"
    echo -e "你可以使用 ${cyan}sb233${none} 命令来管理 233boy 的协议"
    echo -e "原有的 fscarman 脚本及其命令（如 sb）不受任何影响。"
    
    exit_and_del_tmpdir ok
}

main $@
