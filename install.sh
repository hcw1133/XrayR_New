#!/bin/bash

# XrayR installer for the Null404-0/XrayR fork.
# Original install.sh from XrayR-project/XrayR-release is no longer available,
# so this script downloads pre-built binaries directly from this fork's GitHub Releases.
#
# Usage:
#   wget -N https://raw.githubusercontent.com/Null404-0/XrayR/main/install.sh && bash install.sh
#   bash install.sh <version>     # install a specific version, e.g. v0.6.0
#
# Environment overrides:
#   XRAYR_REPO       GitHub repo to pull releases from (default: Null404-0/XrayR)
#   XRAYR_BRANCH     Branch used for raw URLs / management script self-update (default: main)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

REPO="${XRAYR_REPO:-Null404-0/XrayR}"
BRANCH="${XRAYR_BRANCH:-main}"
INSTALL_DIR="/etc/XrayR"
BIN_LINK="/usr/local/XrayR"

cur_dir="$(pwd)"

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain}必须使用 root 用户运行此脚本！\n" && exit 1

# ---------- OS detection ----------
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif grep -qiE "debian" /etc/issue 2>/dev/null; then
    release="debian"
elif grep -qiE "ubuntu" /etc/issue 2>/dev/null; then
    release="ubuntu"
elif grep -qiE "centos|red hat|redhat" /etc/issue 2>/dev/null; then
    release="centos"
elif grep -qiE "debian" /proc/version 2>/dev/null; then
    release="debian"
elif grep -qiE "ubuntu" /proc/version 2>/dev/null; then
    release="ubuntu"
elif grep -qiE "centos|red hat|redhat" /proc/version 2>/dev/null; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本维护者！${plain}\n" && exit 1
fi

# ---------- Architecture detection ----------
# Map uname output to the friendlyName used by the GitHub Actions release workflow
# (see .github/build/friendly-filenames.json).
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
        ppc64)           echo "linux-ppc64" ;;
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

# ---------- Glibc check ----------
check_glibc_version() {
    local ver
    ver="$(ldd --version 2>/dev/null | awk 'NR==1{print $NF}')"
    if [[ -z "$ver" ]]; then return 0; fi
    if [[ "$(printf '%s\n2.17\n' "$ver" | sort -V | head -n1)" != "2.17" ]]; then
        echo -e "${yellow}警告：检测到 glibc 版本 ${ver} 较旧，可能无法运行 XrayR。${plain}"
    fi
}

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
        # Allow user to pass either "v0.6.0" or "0.6.0"
        [[ "$v" != v* ]] && v="v$v"
        echo "$v"
        return
    fi
    # Query GitHub for the latest release tag.
    v="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)"$/\1/')"
    echo "$v"
}

# ---------- Download & install ----------
install_xrayr() {
    local version="$1"
    if [[ -z "$version" ]]; then
        echo -e "${red}无法获取最新版本号，请检查网络或手动指定版本：${plain}"
        echo -e "    bash install.sh v0.6.0"
        exit 1
    fi

    local file="XrayR-${ASSET_NAME}.zip"
    local url="https://github.com/${REPO}/releases/download/${version}/${file}"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1

    echo -e "开始下载 XrayR ${version} (${ASSET_NAME})..."
    if ! wget -q -O "$file" --no-check-certificate "$url"; then
        echo -e "${red}下载失败，URL：${url}${plain}"
        echo -e "${yellow}请确认仓库 ${REPO} 已发布对应版本 ${version}，且产物名为 ${file}。${plain}"
        echo -e "${yellow}如果是首次使用，请先在 GitHub 上手动触发 Release Workflow 生成构建产物。${plain}"
        exit 1
    fi

    rm -f XrayR
    unzip -o "$file" >/dev/null && rm -f "$file"
    chmod +x XrayR

    # Symlink to a stable path so the service file is version-independent.
    ln -sfn "$INSTALL_DIR" "$BIN_LINK"

    # Preserve existing config; only seed a default one on first install.
    if [[ ! -f "$INSTALL_DIR/config.yml" ]]; then
        :  # the zip already contains config.yml seeded from main/config.yml.example
    fi

    write_service
    write_cli

    systemctl daemon-reload
    systemctl enable XrayR >/dev/null 2>&1
    echo -e "${green}XrayR ${version} 安装完成。${plain}"
}

write_service() {
    cat >/etc/systemd/system/XrayR.service <<'EOF'
[Unit]
Description=XrayR Service
Documentation=https://github.com/Null404-0/XrayR
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Group=root
NoNewPrivileges=true
ExecStart=/etc/XrayR/XrayR -config /etc/XrayR/config.yml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
}

write_cli() {
    cat >/usr/bin/xrayr <<EOF
#!/bin/bash
# XrayR management CLI (auto-generated by install.sh)
XRAYR_REPO="${REPO}"
XRAYR_BRANCH="${BRANCH}"
EOF
    cat >>/usr/bin/xrayr <<'EOF'

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

show_status() {
    systemctl is-active --quiet XrayR && echo -e "${green}XrayR 正在运行${plain}" || echo -e "${yellow}XrayR 已停止${plain}"
}

usage() {
    cat <<USAGE
XrayR 管理脚本

用法: xrayr <命令>

命令:
    start       启动 XrayR
    stop        停止 XrayR
    restart     重启 XrayR
    status      查看运行状态
    enable      设置开机自启
    disable     取消开机自启
    log         实时查看日志
    update      升级到最新版（或 xrayr update v0.6.0 指定版本）
    install     重新执行安装脚本
    uninstall   卸载 XrayR
    config      编辑配置文件
    version     显示版本号
    help        显示本帮助
USAGE
}

cmd_update() {
    local ver="$1"
    local installer="https://raw.githubusercontent.com/${XRAYR_REPO}/${XRAYR_BRANCH}/install.sh"
    bash <(curl -fsSL "$installer") "$ver"
}

cmd_uninstall() {
    read -rp "确定要卸载 XrayR 吗？(y/N) " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && return 0
    systemctl stop XrayR 2>/dev/null
    systemctl disable XrayR 2>/dev/null
    rm -f /etc/systemd/system/XrayR.service
    systemctl daemon-reload
    rm -rf /etc/XrayR /usr/local/XrayR
    rm -f /usr/bin/xrayr
    echo -e "${green}XrayR 已卸载。${plain}"
}

case "$1" in
    start)     systemctl start XrayR && show_status ;;
    stop)      systemctl stop XrayR && show_status ;;
    restart)   systemctl restart XrayR && show_status ;;
    status)    systemctl status XrayR --no-pager ;;
    enable)    systemctl enable XrayR && echo -e "${green}已设置开机自启${plain}" ;;
    disable)   systemctl disable XrayR && echo -e "${yellow}已取消开机自启${plain}" ;;
    log)       journalctl -u XrayR -f --no-pager ;;
    update)    cmd_update "$2" ;;
    install)   cmd_update "$2" ;;
    uninstall) cmd_uninstall ;;
    config)    ${EDITOR:-vi} /etc/XrayR/config.yml ;;
    version)   /etc/XrayR/XrayR -version 2>/dev/null || /etc/XrayR/XrayR --version 2>/dev/null ;;
    ""|help|-h|--help) usage ;;
    *) echo -e "${red}未知命令: $1${plain}"; usage; exit 1 ;;
esac
EOF
    chmod +x /usr/bin/xrayr
}

# ---------- Entry point ----------
echo -e "${green}XrayR 安装脚本 (fork: ${REPO})${plain}"
check_glibc_version
install_base

VERSION="$(resolve_version "$1")"
install_xrayr "$VERSION"

echo
echo -e "安装目录: ${INSTALL_DIR}"
echo -e "配置文件: ${INSTALL_DIR}/config.yml"
echo -e "管理命令: ${green}xrayr${plain} (运行 ${green}xrayr help${plain} 查看帮助)"
echo
echo -e "下一步:"
echo -e "  1. 编辑配置: ${green}xrayr config${plain}"
echo -e "  2. 启动服务: ${green}xrayr start${plain}"
echo -e "  3. 查看日志: ${green}xrayr log${plain}"
