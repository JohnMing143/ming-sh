# Project instructions

## Project goal

This repository is a customized Linux server management toolkit derived from
kejilion/sh under the Apache License 2.0.

## Safety rules

- Never execute the main installation script directly.
- Never use `sudo` unless explicitly authorized.
- Never modify the host system, firewall, networking, cron, Docker, systemd,
  package manager, SSH configuration, or files outside this repository.
- Never pipe remote scripts into a shell.
- Do not reintroduce project telemetry or usage-statistics reporting.
- Do not introduce new remote reporting endpoints or services.
- Record newly discovered high-risk commands in `SECURITY_AUDIT.md`.
- After completing and validating a requested change, create one or more small,
  reviewable local commits unless the user explicitly asks not to commit.
- Never push commits or create releases unless explicitly requested.
- Preserve the `LICENSE` file and required upstream copyright notices.

## Development workflow

- Inspect before editing.
- Make small, reviewable changes that address one related group of content.
- Do not combine branding changes, functional changes, and refactoring in one
  change.
- Preserve existing behavior unless the task explicitly changes it.
- After each edit, show the changed files and summarize the behavioral impact.
- Run available checks after each change.
- Prefer `bash -n` and ShellCheck where applicable.

## Repository layout

```text
ming.sh                         Canonical implementation and stable entrypoint
cn|en|jp|kr|tw/ming.sh          Localized implementations
config/project.conf             Canonical source for project and upstream settings
tests/                          Safety regressions and OpenClaw smoke tests
SECURITY_AUDIT.md               High-risk command and trust-boundary audit
```

`cn/ming.sh` must stay byte-identical to the root entrypoint except for the
`canshu="CN"` variant marker; regenerate it from `ming.sh` instead of editing
it directly (`tests/tests_variant_sync.sh` enforces this). The translated
variants must receive every functional change applied to the root script.

Some templates exist as same-name variants for different scenarios, not as
redundant copies:

| File pair | Difference |
| --- | --- |
| `www.conf` / `www-1.conf` | PHP-FPM pool config; no suffix is the high-performance profile, `-1` is the standard (low-resource) profile |
| `custom_mysql_config.cnf` / `custom_mysql_config-1.cnf` | MySQL config; no suffix is the high-performance profile, `-1` is the standard profile |
| `auto_cert_renewal.sh` / `auto_cert_renewal-1.sh` | Certificate renewal; no suffix targets this project's `/home/web/certs` layout, `-1` targets the certbot `/etc/letsencrypt/live` layout |
| `Limiting_Shut_down1.sh` | Traffic-based shutdown template. The `1` suffix is kept because installed entrypoints fetch this exact filename by URL; the legacy unsuffixed implementation was removed on 2026-07-19 |

## Architecture direction

- Gradually split the large shell script into modules.
- Keep one stable entrypoint.
- Centralize branding, repository URLs, version information, telemetry settings,
  installation paths, and update sources in configuration variables.
- Avoid duplicated hard-coded URLs and names.

## Required validation

At minimum, run:

- `bash -n` on every changed shell file.
- ShellCheck on changed shell files when available.
- Grep searches for deprecated branding and endpoints.
- `git diff --check`.
- A `git diff` review before completion.
