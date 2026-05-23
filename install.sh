#!/bin/bash

# XrayR installer / manager for Null404-0/XrayR
# Sources the upstream code from this fork's GitHub Releases and provides
# the classic interactive management menu under the `xrayr` command.
#
# Direct install:
#   wget -N https://raw.githubusercontent.com/Null404-0/XrayR/main/install.sh && bash install.sh
#
# Specific version:
#   bash install.sh v0.6.2
#
# Environment overrides:
#   XRAYR_REPO     Repo to pull releases from        (default: Null404-0/XrayR)
#   XRAYR_BRANCH   Branch for raw-URL self-update    (default: main)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

REPO="${XRAYR_REPO:-Null404-0/XrayR}"
BRANCH="${XRAYR_BRANCH:-main}"
INSTALL_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
CLI_PATH="/usr/bin/xrayr"

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain}必须使用 root 用户运行此脚本！\n" && exit 1

# ---------- OS detection ----------
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -qiE "debian"  /etc/issue 2>/dev/null || grep -qiE "debian"  /proc/version 2>/dev/null; then
    release="debian"
elif grep -qiE "ubuntu"  /etc/issue 2>/dev/null || grep -qiE "ubuntu"  /proc/version 2>/dev/null; then
    release="ubuntu"
elif grep -qiE "centos|red hat|redhat" /etc/issue 2>/dev/null || grep -qiE "centos|red hat|redhat" /proc/version 2>/dev/null; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本维护者！${plain}\n" && exit 1
fi

# ---------- Architecture detection ----------
detect_arch() {
    local uarch
    uarch="$(uname -m)"
    case "$uarch" in
        x86_64|amd64)    echo "linux-64" ;;
        i386|i686)       echo "linux-32" ;;
        aarch64|arm64)   echo "linux-arm64-v8a" ;;
        armv7l|armv7)    echo "linux-arm32-v7a" ;;
        armv6l|armv6)    echo "linux-arm32-v6" ;;
        armv5*)          echo "linux-arm32-v5" ;;
        s390x)           echo "linux-s390x" ;;
        riscv64)         echo "linux-riscv64" ;;
        ppc64le)         echo "linux-ppc64le" ;;
        mips64)          echo "linux-mips64" ;;
        mips64le)        echo "linux-mips64le" ;;
        mips)            echo "linux-mips32" ;;
        mipsle|mipsel)   echo "linux-mips32le" ;;
        *)               echo "" ;;
    esac
}

ASSET_NAME="$(detect_arch)"
if [[ -z "$ASSET_NAME" ]]; then
    echo -e "${red}不支持的架构：$(uname -m)${plain}" && exit 1
fi

# ---------- Dependencies ----------
install_base() {
    if [[ "$release" == "centos" ]]; then
        yum install -y -q wget curl tar unzip ca-certificates >/dev/null 2>&1
    else
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq wget curl tar unzip ca-certificates >/dev/null 2>&1
    fi
}

# ---------- Version resolution ----------
resolve_version() {
    local v="$1"
    if [[ -n "$v" ]]; then
        [[ "$v" != v* ]] && v="v$v"
        echo "$v"; return
    fi
    v="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)"$/\1/')"
    echo "$v"
}

# ---------- Service file ----------
write_service() {
    cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=XrayR Service
Documentation=https://github.com/Null404-0/XrayR
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Group=root
NoNewPrivileges=true
WorkingDirectory=/etc/XrayR
ExecStart=/etc/XrayR/XrayR -c /etc/XrayR/config.yml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
}

# ---------- Install / update ----------
install_xrayr() {
    local version="$1"
    if [[ -z "$version" ]]; then
        echo -e "${red}无法获取最新版本号，请检查网络或手动指定版本：${plain}"
        echo -e "    bash install.sh v0.6.2"
        return 1
    fi

    local file="XrayR-${ASSET_NAME}.zip"
    local url="https://github.com/${REPO}/releases/download/${version}/${file}"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || return 1

    echo -e "开始下载 XrayR ${green}${version}${plain} (${ASSET_NAME})..."
    if ! wget -q -O "$file" --no-check-certificate "$url"; then
        echo -e "${red}下载失败，URL：${url}${plain}"
        return 1
    fi

    # Preserve user config files; only seed defaults if missing.
    rm -f XrayR
    unzip -o "$file" -x config.yml dns.json route.json custom_inbound.json custom_outbound.json rulelist >/dev/null
    # Always extract these to a staging area so we can seed defaults conditionally.
    local stage
    stage="$(mktemp -d)"
    unzip -o "$file" -d "$stage" config.yml dns.json route.json custom_inbound.json custom_outbound.json rulelist >/dev/null 2>&1 || true
    for f in config.yml dns.json route.json custom_inbound.json custom_outbound.json rulelist; do
        if [[ -f "$stage/$f" && ! -f "$INSTALL_DIR/$f" ]]; then
            cp "$stage/$f" "$INSTALL_DIR/$f"
        fi
    done
    rm -rf "$stage" "$file"
    chmod +x XrayR

    write_service
    write_cli
    systemctl daemon-reload
    systemctl enable XrayR >/dev/null 2>&1
    echo -e "${green}XrayR ${version} 已安装完成。${plain}"
}

# ---------- CLI generator ----------
write_cli() {
    cat >"$CLI_PATH" <<EOF
#!/bin/bash
# XrayR 管理脚本 (由 install.sh 生成)
XRAYR_REPO="${REPO}"
XRAYR_BRANCH="${BRANCH}"
EOF
    cat >>"$CLI_PATH" <<'MENU_EOF'

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

INSTALL_DIR="/etc/XrayR"
CONFIG_FILE="${INSTALL_DIR}/config.yml"

confirm() {
    local prompt="$1" default="${2:-n}" reply
    if [[ "$default" == "y" ]]; then
        read -rp "${prompt} [Y/n]: " reply
        [[ -z "$reply" ]] && reply="y"
    else
        read -rp "${prompt} [y/N]: " reply
        [[ -z "$reply" ]] && reply="n"
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

pause_back() {
    echo ""
    read -rp "按回车键返回主菜单..." _ </dev/tty 2>/dev/null || true
}

run_installer() {
    local ver="$1"
    local url="https://raw.githubusercontent.com/${XRAYR_REPO}/${XRAYR_BRANCH}/install.sh"
    bash <(curl -fsSL "$url") "$ver"
}

show_status_line() {
    if systemctl is-active --quiet XrayR; then
        echo -e "XrayR状态: ${green}已运行${plain}"
    elif [[ -f /etc/XrayR/XrayR ]]; then
        echo -e "XrayR状态: ${yellow}未运行${plain}"
    else
        echo -e "XrayR状态: ${red}未安装${plain}"
    fi
    if systemctl is-enabled --quiet XrayR 2>/dev/null; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

# ---------- actions ----------
config_edit()  { ${EDITOR:-vi} "$CONFIG_FILE"; }
install_act()  { run_installer ""; }
update_act()   {
    read -rp "请输入要更新到的版本(回车=最新): " v </dev/tty
    run_installer "$v"
}
uninstall_act() {
    confirm "确定要卸载 XrayR 吗？" n || return 0
    systemctl stop XrayR 2>/dev/null
    systemctl disable XrayR 2>/dev/null
    rm -f /etc/systemd/system/XrayR.service
    systemctl daemon-reload
    rm -rf /etc/XrayR
    rm -f /usr/bin/xrayr
    echo -e "${green}XrayR 已卸载。${plain}"
}
start_act()    { systemctl start XrayR && echo -e "${green}XrayR 已启动${plain}"; }
stop_act()     { systemctl stop XrayR && echo -e "${yellow}XrayR 已停止${plain}"; }
restart_act()  { systemctl restart XrayR && echo -e "${green}XrayR 已重启${plain}"; }
status_act()   { systemctl status XrayR --no-pager; }
log_act()      {
    echo -e "${yellow}按 Ctrl+C 退出日志${plain}"
    journalctl -u XrayR -f --no-pager
}
enable_act()   { systemctl enable XrayR && echo -e "${green}已设置开机自启${plain}"; }
disable_act()  { systemctl disable XrayR && echo -e "${yellow}已取消开机自启${plain}"; }
install_bbr()  {
    bash <(curl -fsSL https://github.com/teddysun/across/raw/master/bbr.sh)
}
version_act()  {
    if [[ -x /etc/XrayR/XrayR ]]; then
        /etc/XrayR/XrayR version
    else
        echo -e "${red}XrayR 未安装${plain}"
    fi
}
selfupdate_act() {
    local url="https://raw.githubusercontent.com/${XRAYR_REPO}/${XRAYR_BRANCH}/install.sh"
    echo -e "${yellow}从 ${url} 重新拉取脚本，会顺带把 XrayR 升到最新版${plain}"
    confirm "继续？" y || return 0
    bash <(curl -fsSL "$url")
}

# ---------- menu ----------
show_menu() {
    clear
    echo -e "${green}XrayR 后端管理脚本${plain}，${red}不适用于 docker${plain}"
    echo -e "--- https://github.com/${XRAYR_REPO} ---"
    echo -e "  ${green}0.${plain}  修改配置"
    echo -e "————————————————"
    echo -e "  ${green}1.${plain}  安装 XrayR"
    echo -e "  ${green}2.${plain}  更新 XrayR"
    echo -e "  ${green}3.${plain}  卸载 XrayR"
    echo -e "————————————————"
    echo -e "  ${green}4.${plain}  启动 XrayR"
    echo -e "  ${green}5.${plain}  停止 XrayR"
    echo -e "  ${green}6.${plain}  重启 XrayR"
    echo -e "  ${green}7.${plain}  查看 XrayR 状态"
    echo -e "  ${green}8.${plain}  查看 XrayR 日志"
    echo -e "————————————————"
    echo -e "  ${green}9.${plain}  设置 XrayR 开机自启"
    echo -e " ${green}10.${plain}  取消 XrayR 开机自启"
    echo -e "————————————————"
    echo -e " ${green}11.${plain}  一键安装 bbr (最新内核)"
    echo -e " ${green}12.${plain}  查看 XrayR 版本"
    echo -e " ${green}13.${plain}  升级维护脚本"
    echo -e ""
    show_status_line
    echo -e ""
    read -rp "请输入选择 [0-13]: " choice
    case "$choice" in
        0)  config_edit; pause_back ;;
        1)  install_act; pause_back ;;
        2)  update_act; pause_back ;;
        3)  uninstall_act; pause_back ;;
        4)  start_act; pause_back ;;
        5)  stop_act; pause_back ;;
        6)  restart_act; pause_back ;;
        7)  status_act; pause_back ;;
        8)  log_act ;;
        9)  enable_act; pause_back ;;
        10) disable_act; pause_back ;;
        11) install_bbr; pause_back ;;
        12) version_act; pause_back ;;
        13) selfupdate_act; pause_back ;;
        q|Q|"") exit 0 ;;
        *)  echo -e "${red}无效输入${plain}"; sleep 1 ;;
    esac
}

# ---------- subcommand mode (xrayr <cmd>) ----------
case "$1" in
    start)     start_act ;;
    stop)      stop_act ;;
    restart)   restart_act ;;
    status)    status_act ;;
    enable)    enable_act ;;
    disable)   disable_act ;;
    log)       log_act ;;
    update)    run_installer "$2" ;;
    install)   install_act ;;
    uninstall) uninstall_act ;;
    config)    config_edit ;;
    version)   version_act ;;
    bbr)       install_bbr ;;
    help|-h|--help)
        cat <<USAGE
XrayR 管理脚本

直接运行 ${0##*/} 进入交互菜单，或使用子命令：

  start      启动 XrayR
  stop       停止 XrayR
  restart    重启 XrayR
  status     查看运行状态
  enable     设置开机自启
  disable    取消开机自启
  log        实时查看日志
  update     更新到最新版（xrayr update v0.6.2 指定版本）
  install    重新执行安装脚本
  uninstall  卸载 XrayR
  config     编辑配置文件
  version    显示版本号
  bbr        一键安装 BBR (调用 teddysun/across 脚本)
USAGE
        ;;
    "")        while true; do show_menu; done ;;
    *)         echo -e "${red}未知命令: $1${plain}"; exit 1 ;;
esac
MENU_EOF
    chmod +x "$CLI_PATH"
}

# ---------- Entry point ----------
echo -e "${green}XrayR 安装脚本 (源: ${REPO})${plain}"
install_base
VERSION="$(resolve_version "$1")"
install_xrayr "$VERSION" || exit 1

echo ""
echo -e "安装目录: ${INSTALL_DIR}"
echo -e "配置文件: ${INSTALL_DIR}/config.yml"
echo -e "管理命令: ${green}xrayr${plain} (直接运行进入交互菜单)"
echo ""
echo -e "下一步:"
echo -e "  1. 编辑配置: ${green}xrayr${plain}  → 选择 ${green}0${plain}"
echo -e "  2. 启动服务: ${green}xrayr${plain}  → 选择 ${green}4${plain}"
echo -e "  3. 查看日志: ${green}xrayr${plain}  → 选择 ${green}8${plain}"
