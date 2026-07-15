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
