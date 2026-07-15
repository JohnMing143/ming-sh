# ming.sh

个人使用的 Linux 服务器管理工具箱，基于
[kejilion/sh](https://github.com/kejilion/sh) 按 Apache License 2.0
进行定制。

[繁體中文](README.tw.md) · [日本語](README.ja.md) · [한국어](README.kr.md)

> [!WARNING]
> 本项目包含修改防火墙、网络、SSH、cron、Docker、systemd、软件包和
> `/etc`、`/usr`、`/home` 下文件的高权限功能。请先审阅代码，在测试机验证，
> 再以适当权限运行。不要把远程脚本直接传给 shell。

## 当前个性化默认值

| 项目 | 默认值 |
| --- | --- |
| 项目名 | `ming.sh` |
| 主命令 | `m` |
| 仓库 | `JohnMing143/ming-sh` |
| 主入口 | `ming.sh` |
| 安装路径 | `/usr/local/bin/m` |
| 开发用远程翻译 | 默认禁用，需显式设置 `ALLOW_REMOTE_TRANSLATION=true` |
| 项目自更新 | 禁用 |
| 自动更新 cron | 禁用 |
| GitHub 代理 | 留空，直接访问 |
| 波斯语、俄语入口 | 已移除 |

项目身份、仓库地址、安装路径、更新策略、系统路径和上游依赖统一在
[`config/project.conf`](config/project.conf) 中维护。独立下载的入口脚本包含相同的
安全回退值，因此不依赖配置文件也不会重新启用项目自更新。项目源码不包含
使用统计上报逻辑。

## 主要功能

- 系统信息、更新、清理和基础工具管理
- Docker、容器、镜像和应用管理
- LNMP、站点、证书、备份和迁移
- BBR、内核、网络和防火墙管理
- SSH、磁盘、rsync、集群和后台任务工具
- OpenClaw、游戏服务器和其他辅助模块

这些普通功能仍会按用户选择访问其软件上游、下载依赖或修改系统。项目自更新
仍保持禁用，项目源码不包含使用统计上报逻辑。

开发用翻译脚本会把待翻译源码片段发送给 Google Translate，因此默认拒绝运行；
仅在审阅输入后显式设置 `ALLOW_REMOTE_TRANSLATION=true`。

## 审阅后安装

仓库上传到 GitHub 后，可先下载到本地文件，再检查并运行：

```bash
curl -fL --output ming.sh \
  https://raw.githubusercontent.com/JohnMing143/ming-sh/main/ming.sh
bash -n ming.sh
less ming.sh
bash ming.sh
```

不要使用 `curl ... | bash` 或 `bash <(curl ...)`。保留语言入口可将下载地址改为：

```text
cn/ming.sh
en/ming.sh
jp/ming.sh
kr/ming.sh
tw/ming.sh
```

首次运行只部署 `/usr/local/bin/m`，并使用 `/etc/sysctl.d/99-ming-sh-*.conf`
及 `# ming-sh-optimize` 标记。新文档和自动化统一使用 `m`。

## 仓库结构

```text
ming.sh                         主实现与稳定入口
cn|en|jp|kr|tw/ming.sh          保留的语言实现
config/project.conf             项目与上游配置的权威来源
tests/                          安全回归与 OpenClaw 冒烟测试
SECURITY_AUDIT.md               高风险命令和安全边界审计
```

部分模板存在同名变体，属于不同场景而非冗余副本：

| 文件对 | 区别 |
| --- | --- |
| `www.conf` / `www-1.conf` | PHP-FPM 池配置；无后缀为高性能模式，`-1` 为标准（低资源）模式 |
| `custom_mysql_config.cnf` / `custom_mysql_config-1.cnf` | MySQL 配置；无后缀为高性能模式，`-1` 为标准模式 |
| `auto_cert_renewal.sh` / `auto_cert_renewal-1.sh` | 证书续签；无后缀用于本项目 `/home/web/certs` 布局，`-1` 用于 certbot `/etc/letsencrypt/live` 布局 |
| `Limiting_Shut_down.sh` / `Limiting_Shut_down1.sh` | 流量关机脚本；主入口部署 `Limiting_Shut_down1.sh`，无后缀为旧版实现 |

大型入口仍是单体 Bash 文件。后续模块化应保持一个稳定入口，并分别拆分配置、
系统、网络、Docker、站点和应用功能，避免把品牌替换、行为修改和重构混在一起。

## 命名与迁移策略

- `m` 是唯一默认命令，`ming.sh` 是唯一项目入口命名。
- 新安装只创建 ming-sh 命名的脚本、命令、调优文件和标记。
- 仓库不再提供旧品牌文件名包装器，也不会创建旧命令链接。
- 已有机器上的旧品牌文件、链接、调优配置和 cron 任务不会被自动删除，需要
  管理员自行审阅并清理。

## 上游依赖

为保持普通功能，部分 Nginx 模板、Docker Compose 文件、应用仓库、站点素材、
Docker 镜像以及 Palworld 配置仍来自上游项目。所有这类地址和镜像名都集中为
`UPSTREAM_*` 变量；它们不是遥测端点。完整清单见
[`config/project.conf`](config/project.conf) 和
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md)。

## 开发与验证

不要直接执行主脚本进行开发验证。可运行：

```bash
bash -n ming.sh cn/ming.sh en/ming.sh jp/ming.sh kr/ming.sh tw/ming.sh
bash tests/tests_project_safety_defaults.sh
bash tests/tests_command_construction_safety.sh
bash tests/tests_openclaw_config_path_resolution_smoke.sh
bash tests/tests_translation_privacy_defaults.sh
bash tests_openclaw_manager_smoke.sh
for test_file in tests/openclaw/*.sh; do bash "$test_file"; done
git diff --check
```

当前大型单体入口不运行 ShellCheck；在完成模块化、解决其资源占用问题前，
使用 `bash -n`、针对性静态检查和回归测试验证。

OpenClaw 测试使用仓库内临时目录和 stub，详见
[`tests/openclaw/README.md`](tests/openclaw/README.md)。会启动容器并可能拉取镜像的
Docker 矩阵不属于默认本地验证。

## 许可证与归属

本仓库保留 Apache License 2.0 的 [`LICENSE`](LICENSE) 文件和必要的上游归属。
个性化名称不表示对原作者版权或许可证声明的移除。
