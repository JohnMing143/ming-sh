# ming.sh

An all-in-one Linux server management toolkit. After installation, a single
`m` command opens an interactive menu for everyday operations: system
maintenance, Docker, website hosting, network tuning, and more.

[简体中文](README.md) · [繁體中文](README.tw.md) · [日本語](README.ja.md) · [한국어](README.kr.md)

## Features

- **System management**: system info, updates, cleanup, common base tools
- **Docker management**: install and maintain containers, images, networks, and
  volumes; one-click deployment of common applications
- **Hosting and operations**: LNMP stack, site management, SSL certificates,
  backup and migration
- **Network tuning**: BBR acceleration, kernel tuning, firewall and port control
- **Utilities**: SSH hardening, disk management, rsync sync, cluster management,
  background tasks
- **Add-on modules**: OpenClaw, game servers (Palworld, Minecraft), and more

## Installation

A single command installs and launches it:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JohnMing143/ming-sh/main/en/ming.sh)
```

The first run installs the command to `/usr/local/bin/m`; afterwards, type `m`
in any directory to open the main menu.

For other language versions, replace `ming.sh` in the download path with:

```text
cn/ming.sh    简体中文 (Simplified Chinese)
en/ming.sh    English
jp/ming.sh    日本語 (Japanese)
kr/ming.sh    한국어 (Korean)
tw/ming.sh    繁體中文 (Traditional Chinese)
```

## Usage

```bash
m
```

Choose a feature by its menu number. Each feature explains what it will do
before running; anything that downloads dependencies or modifies the system
happens only when you actively select the corresponding menu item.

System-tuning features use `/etc/sysctl.d/99-ming-sh-*.conf` files and the
`# ming-sh-optimize` marker; the network auto-tune mode uses
`/etc/sysctl.d/99-ming-sh-network.conf` (the legacy `99-network-optimize.conf`
path is migrated automatically at runtime), so they are easy to identify and
clean up.

## Privacy and security defaults

- **No usage statistics**: the source contains no telemetry or reporting logic.
- **No automatic updates**: project self-update and auto-update cron jobs are
  disabled; updates are entirely under your control.
- **Direct GitHub access**: no GitHub proxy is used by default.
- **Transparent dependency sources**: some Nginx templates, Docker Compose
  files, and Docker images still come from upstream projects; all their
  addresses are kept in [`config/project.conf`](config/project.conf) as
  `UPSTREAM_*` variables, with the full list in
  [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md).
- **Offline translation tooling by default**: language variants are generated
  offline from the in-repo translation catalogs; only the command that
  backfills newly added text sends source fragments to Google Translate, and it
  runs only when `ALLOW_REMOTE_TRANSLATION=true` is set explicitly.

## Contributing

Development validation, repository layout, and testing notes are in
[`AGENTS.md`](AGENTS.md) and the [`tests/`](tests) directory; the trust-boundary
audit is in [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md).

## Upstream and license

This project is customized from [kejilion/sh](https://github.com/kejilion/sh)
and licensed under the Apache License 2.0. The repository keeps the
[`LICENSE`](LICENSE) file and the required upstream attribution; the
personalized name does not remove the original author's copyright or license
notices.
