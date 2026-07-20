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

Every localized entrypoint is generated from the root script — never edit
one directly. `cn/ming.sh` is the root with only the `canshu="CN"` marker
changed; `en|jp|kr|tw/ming.sh` substitute translated lines from
`<lang>/catalog.json`. After changing `ming.sh`, run
`python3 translate.py generate --all` and commit the regenerated variants
(plus catalog updates when translations change). `tests/tests_variant_sync.sh`,
`tests/tests_variant_structure_sync.sh`, and
`tests/tests_variant_generation_sync.sh` enforce this; new untranslated lines
are allowed to pass through in Chinese and are listed by
`python3 translate.py status --all`. Translating them remotely
(`translate-missing`) is optional and gated by `ALLOW_REMOTE_TRANSLATION=true`.

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
