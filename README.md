# XrayR

![](https://img.shields.io/github/stars/Null404-0/XrayR)
![](https://github.com/Null404-0/XrayR/actions/workflows/release.yml/badge.svg)
[![Github All Releases](https://img.shields.io/github/downloads/Null404-0/XrayR/total.svg)]()

> **Fork 说明**：上游 [`XrayR-project/XrayR`](https://github.com/XrayR-project/XrayR) 已标记「项目已废弃」。本仓库基于上游 `v25.3.6` 最后一个完整源码快照，仅做必要适配（CI 流水线、一键脚本、Debian/Ubuntu 部署优化），用于自用 VPS 后端部署。不接受新功能 PR；安全修复或上游 bug 的 backport 视情况合并。

一个基于 Xray 的后端框架，支持 V2ray、Trojan、Shadowsocks 协议，对接 SSpanel / V2board / PMPanel / ProxyPanel / V2RaySocks / GoV2Panel / BunPanel 等面板。

## 特点

* 支持 V2ray、Trojan、Shadowsocks 多种协议
* 支持 Vless、XTLS、REALITY 等新特性
* 支持单实例对接多面板、多节点
* 支持节点端口级、用户级限速 + AutoSpeedLimit 自动惩罚
* 支持 Redis 后端的全局设备数限制
* 支持自动申请 / 续签 TLS 证书（DNS / HTTP / 文件三种模式）
* 配置文件热重载

## 软件安装

### 一键安装（推荐）

```bash
wget -N https://raw.githubusercontent.com/hcw1133/XrayR_New/main/install.sh && bash install.sh
```

脚本会自动：

1. 检测系统（Debian / Ubuntu / CentOS）与 CPU 架构
2. 安装依赖（wget、curl、unzip、ca-certificates）
3. 从本仓库 Releases 拉取对应架构的最新二进制
4. 写入 systemd 单元 `XrayR.service`
5. 生成管理命令 `/usr/bin/xrayr`

安装完成后输入 `xrayr` 即可进入交互菜单。

### 指定版本安装

```bash
wget -N https://raw.githubusercontent.com/hcw1133/XrayR_New/main/install.sh && bash install.sh v0.9.5
```

### 支持的架构

每次 release 只构建 Debian/Ubuntu 常用的三组：

| `uname -m`    | 对应 zip                       | 典型 VPS                                 |
| ------------- | ---------------------------- | -------------------------------------- |
| `x86_64`      | `XrayR-linux-64.zip`         | Vultr / Linode / DO / AWS x86          |
| `aarch64`     | `XrayR-linux-arm64-v8a.zip`  | Oracle Ampere / AWS Graviton / RPi 4 64-bit |
| `armv7l`      | `XrayR-linux-arm32-v7a.zip`  | 老 ARM 主机 / RPi 32-bit / 软路由           |

需要其他平台（windows / darwin / freebsd / mips / riscv 等）请自行 `go build`，源码在仓库根目录。

## 管理命令

直接运行 `xrayr` 进入交互菜单：

```
  0.  修改配置
  1.  安装 XrayR
  2.  更新 XrayR
  3.  卸载 XrayR
  4.  启动 XrayR
  5.  停止 XrayR
  6.  重启 XrayR
  7.  查看 XrayR 状态
  8.  查看 XrayR 日志
  9.  设置 XrayR 开机自启
 10.  取消 XrayR 开机自启
 11.  一键安装 bbr (最新内核)
 12.  查看 XrayR 版本
 13.  升级维护脚本
```

也支持子命令形式，方便写脚本：

```bash
xrayr start       # 启动
xrayr stop        # 停止
xrayr restart     # 重启
xrayr status      # 查看运行状态
xrayr log         # 实时查看日志（Ctrl+C 退出）
xrayr config      # 用 $EDITOR 打开配置文件
xrayr enable      # 设置开机自启
xrayr disable     # 取消开机自启
xrayr update      # 升级到最新版（xrayr update v0.9.2 指定版本）
xrayr uninstall   # 卸载
xrayr version     # 显示版本
xrayr bbr         # 调用 teddysun BBR 安装脚本
```

## 配置文件

* 主配置：`/etc/XrayR/config.yml`
* DNS 配置：`/etc/XrayR/dns.json`
* 路由配置：`/etc/XrayR/route.json`
* 自定义入站：`/etc/XrayR/custom_inbound.json`
* 自定义出站：`/etc/XrayR/custom_outbound.json`
* 本地规则列表：`/etc/XrayR/rulelist`

默认 `config.yml` 注释已汉化，包含 SSpanel + REALITY + AutoSpeedLimit + GlobalDeviceLimit + FallBack 的完整模板。详细字段说明仍可参考上游文档：

* 上游使用文档（仍可用）：<https://xrayr-project.github.io/XrayR-doc/>
* Xray-core 配置参考：<https://xtls.github.io/config/>

## 升级

```bash
xrayr update         # 升到最新
xrayr update v0.9.5  # 升到指定版本
```

升级时已有配置文件会被保留，不会被默认模板覆盖。

## 卸载

```bash
xrayr uninstall
```

会停止服务、移除 systemd 单元、删除 `/etc/XrayR/` 与 `/usr/bin/xrayr`。

## License

[Mozilla Public License Version 2.0](./LICENSE)（沿用上游协议）

## 致谢

* [XrayR-project/XrayR](https://github.com/XrayR-project/XrayR) — 原始项目，本仓库基于其 `v25.3.6` 快照
* [Project X (XTLS)](https://github.com/XTLS/)
* [V2Fly](https://github.com/v2fly)
