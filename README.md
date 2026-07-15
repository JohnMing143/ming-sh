# ming.sh

一站式 Linux 服务器管理工具箱。安装后输入一个 `m` 命令，即可通过交互式菜单
完成系统维护、Docker、建站、网络优化等日常运维工作。

[繁體中文](README.tw.md) · [日本語](README.ja.md) · [한국어](README.kr.md)

## 功能一览

- **系统管理**：系统信息查询、系统更新、垃圾清理、常用基础工具
- **Docker 管理**：容器、镜像、网络、卷的安装与维护，常用应用一键部署
- **建站与运维**：LNMP 环境、站点管理、SSL 证书、备份与迁移
- **网络优化**：BBR 加速、内核调优、防火墙与端口管理
- **实用工具**：SSH 防护、磁盘管理、rsync 同步、集群管理、后台任务
- **附加模块**：OpenClaw、游戏服务器（Palworld、Minecraft）等辅助功能

## 安装

一条命令即可完成安装并启动：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JohnMing143/ming-sh/main/ming.sh)
```

首次运行会把命令安装到 `/usr/local/bin/m`，之后在任意目录输入 `m` 即可打开
主菜单。

如需其他语言版本，把下载路径中的 `ming.sh` 换成：

```text
cn/ming.sh    简体中文
en/ming.sh    English
jp/ming.sh    日本語
kr/ming.sh    한국어
tw/ming.sh    繁體中文
```

## 使用

```bash
m
```

按菜单编号选择功能即可。各功能会在执行前说明将要进行的操作；涉及下载依赖或
修改系统的操作，均只在你主动选择对应菜单项时才会发生。

系统调优相关功能使用 `/etc/sysctl.d/99-ming-sh-*.conf` 配置文件和
`# ming-sh-optimize` 标记，便于识别和清理。

## 隐私与安全默认值

- **无使用统计**：项目源码不包含任何遥测或统计上报逻辑。
- **无自动更新**：项目自更新和自动更新 cron 均已禁用，更新完全由你掌控。
- **直连 GitHub**：默认不使用任何 GitHub 代理。
- **依赖地址透明**：部分 Nginx 模板、Docker Compose 文件、Docker 镜像等仍来自
  上游项目，所有地址集中在 [`config/project.conf`](config/project.conf) 中以
  `UPSTREAM_*` 变量维护，完整清单见 [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。
- **开发用翻译脚本默认禁用**：该脚本会把源码片段发送给 Google Translate，
  仅在显式设置 `ALLOW_REMOTE_TRANSLATION=true` 后才会运行，普通使用无需关心。

## 参与开发

开发验证方式、仓库结构和测试说明见 [`AGENTS.md`](AGENTS.md) 与
[`tests/`](tests) 目录；安全边界审计见 [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。

## 原始仓库与许可证

本项目基于 [kejilion/sh](https://github.com/kejilion/sh) 定制，按
Apache License 2.0 授权。仓库保留了 [`LICENSE`](LICENSE) 文件和必要的上游
归属声明；个性化名称不表示对原作者版权或许可证声明的移除。
