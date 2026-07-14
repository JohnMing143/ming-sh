# Security audit

Audit date: 2026-07-14

## Scope and method

This audit covers every tracked repository file, including the root and
localized entrypoints, helper scripts, configuration templates, translation
tools, tests, and GitHub Actions. Repository logic was reviewed statically;
only the validation commands documented below were intentionally run. The main
installer, Docker matrix, privileged commands, and real system-service,
firewall, networking, cron, or Docker operations were not run.

The localized `ming.sh` implementations largely duplicate the root script.
Unless noted otherwise, line references below use the root `ming.sh`.

## Current privacy and update posture

- `ENABLE_TELEMETRY="false"` is the canonical default.
- Every shell `send_stats` implementation is a local `return 0` no-op.
- The embedded OpenClaw Python compatibility hook is also a no-op and has no
  reporting endpoint.
- The former telemetry endpoint and remote user-agreement URL are absent.
- `PROJECT_UPDATE_URL` and `PROJECT_UPDATE_LOG_URL` are empty.
- `project_update` contains no download, cron, Git, or replacement operation.
- Helper-script self-update options only direct users to manual review.
- The scheduled translation workflow, write permission, commit, and push logic
  have been removed.

These controls do not disable network access required by an explicitly chosen
ordinary feature, such as downloading a package, querying an API configured by
the user, or pulling an application image.

## Privacy-relevant development tooling

The scheduled translation workflow has been removed. However, manually running
`translate.py` or a locale-specific `to-*.py` script sends Chinese source-text
fragments to Google Translate through `deep_translator`. This is not telemetry
and it is never invoked by the main entrypoint, but it can disclose source text
to a third party. Do not run the translators on files containing secrets or
private operational data.

## Architecture and trust boundaries

| Component | Role | Trust boundary |
| --- | --- | --- |
| `ming.sh` | Primary monolithic implementation | Runs high-privilege system functions and installs command links at startup |
| `cn/en/jp/kr/tw/ming.sh` | Localized implementations | Same risk profile as the root implementation |
| `kejilion.sh` and localized copies | Legacy wrappers | Execute only an adjacent local `ming.sh`; do not download a replacement |
| `config/project.conf` | Canonical identity, paths, policy, and upstream sources | Sourced as shell code; only trusted local edits should be used |
| `mc.sh`, `palworld.sh`, `ldnmp.sh`, `hermes_manager.sh` | Standalone feature installers/managers | Perform system writes and execute external tools or installers |
| `tests/` | Static extraction and smoke harnesses | Use temporary homes and command stubs; the Docker matrix remains an explicit exception |

## High-risk command findings

| ID | Risk | Current evidence | Impact | Status |
| --- | --- | --- | --- | --- |
| CMD-001 | Critical: arbitrary command execution | `ming.sh:19702` intentionally accepts a background command and `ming.sh:3273` passes it to tmux as a shell command. | Untrusted or mistaken input can execute arbitrary commands with the script's privileges. | Open by design. The Docker-create and OpenClaw `eval` paths were removed, and the prompt no longer recommends a remote-script pipeline. |
| CMD-002 | Critical: remote code is executed without review or integrity verification | Examples include `ming.sh:529`, `ming.sh:6545`, `ming.sh:8026`, `ming.sh:8836`, `ming.sh:10285`, `ming.sh:10292`, `ming.sh:19435`, `hermes_manager.sh:964`, `ldnmp.sh:25`, `mc.sh:111`, and `palworld.sh:99`. | Compromise of an upstream, DNS path, proxy, or release can become immediate code execution, often as root. | Open. |
| CMD-003 | Critical: TLS verification is disabled for executable downloads | `ming.sh:5367`, `ming.sh:16485`, `ming.sh:16496`, `ming.sh:16978`, `ming.sh:18021`, and `upgrade_openssh9.8p1.sh:56`. | A network attacker may replace executable content. | Open. |
| CMD-004 | High: string-built commands use `eval` | Docker restore now builds `docker_run_args` arrays at `ming.sh:8374-8414`; OpenClaw identity updates use an array at `ming.sh:15355-15363`. | Values that cross quoting boundaries could inject additional shell syntax. | Resolved on 2026-07-14; static regression coverage prevents the former `eval` forms from returning. |
| CMD-005 | Critical: broad deletion and filesystem formatting | Examples include `ming.sh:2932`, `ming.sh:4837`, `ming.sh:5001`, `ming.sh:7375`, `ming.sh:9987`, `mc.sh:303`, `palworld.sh:293`, `mc_backup.sh:6`, and `pal_backup.sh:6`. | A wrong, empty, or manipulated path can irreversibly destroy system or user data. | Open. |
| CMD-006 | High: SSH host verification is disabled | `ming.sh:7163`, `ming.sh:7179`, `ming.sh:7553`, `ming.sh:8436`, `ming.sh:19459`, `ming.sh:21495`, `ming.sh:21549`, and `beifen.sh:7`. | SSH/SCP traffic and credentials are exposed to machine-in-the-middle attacks. | Open. |
| CMD-007 | Critical: unrestricted passwordless sudo is written | `ming.sh:20190` and `ming.sh:20604` create `NOPASSWD:ALL` rules. | Compromise of the selected account becomes unrestricted root access. | Open. |
| CMD-008 | High: firewall and network policy can be broadly cleared | `ming.sh:933`, `ming.sh:1223`, `ldnmp.sh:45`, and `auto_cert_renewal-1.sh:45` flush iptables; many menu functions add broad allow rules. | Services may become publicly reachable and existing protection can be lost. | Open. |
| CMD-009 | High: world-writable permissions are applied recursively | Examples include `ming.sh:15901`, `ming.sh:17639`, `ming.sh:18350`, and `palworld.sh:304`. | Local users or compromised services can modify application data or executable content. | Open. |
| CMD-010 | High: credentials are stored or displayed in plaintext | Cluster passwords are written to `~/cluster/servers.py`; `PandoraNext/config.json` ships `setup_password: webgptpasswd`; `PandoraNext/tokens.json` includes example password `12345`; several application definitions expose fixed initial passwords. | Secrets may leak through backups, process output, shell history, or permissive files. | Open. The token strings are examples, not verified live credentials. |
| CMD-011 | High: startup performs persistent installation writes | `ming.sh:183-208` edits shell startup files, copies itself to the user directory and `/usr/local/bin/m`, and creates legacy links including `/usr/bin/k`. | Merely running the main entrypoint changes persistent host state. | Open and prominently documented; not executed during development. |
| CMD-012 | High: cron is rewritten in many feature paths | Representative writes occur at `ming.sh:919-920`, `ming.sh:1494-1495`, `ming.sh:7625`, `ming.sh:9949-9954`, `ming.sh:20874-20896`, and `ming.sh:21003-21057`. Some commands originate from interactive input. | Incorrect filters can delete unrelated jobs; arbitrary scheduled commands persist with the user's privileges. | Open. Project auto-update cron creation itself is removed. |
| CMD-013 | High: dependencies are mutable and usually unpinned | Installers use `latest`, branch heads, short domains, mutable images, and remote application definitions. | A future upstream change can alter behavior without a repository change. | Open. Project-owned and upstream URLs are centralized, but not integrity-pinned. |
| CMD-014 | High: command aliases can target arbitrary names under system bin directories | `ming.sh:20280-20310` applies a filename allowlist, rejects consecutive dots, and checks both destination paths before creating links. | A crafted or conflicting name could overwrite command paths or create unexpected links. | Resolved on 2026-07-14; existing commands not owned by this project are no longer overwritten. |
| CMD-015 | Medium: test harnesses have unequal isolation | `tests_openclaw_manager_smoke.sh` now uses a repository-local temporary tree, extracted-function boundaries, and command stubs; `run_openclaw_manager_matrix.sh:32` still starts Docker containers and may pull images. | Running the Docker matrix can modify Docker state or require network access. | Partially resolved on 2026-07-14. The standalone manager smoke test is isolated; the Docker matrix remains excluded. |
| CMD-016 | High: generated Docker restore scripts concatenate untrusted metadata | The former generator embedded Compose paths, environment values, volume paths, names, and images directly in shell source. It now uses Bash `printf %q` at `ming.sh:8252-8294`. | Crafted container metadata or paths could add commands that run later when an administrator executes the generated restore script. | Resolved on 2026-07-14; each generated argument is shell-quoted and the live restore path uses arrays. |

## Project and upstream remote sources

Project-owned resources use `PROJECT_DOWNLOAD_BASE`, which defaults to the Raw
URL for `JohnMing143/ming-sh`. Ordinary features still depend on explicitly
named upstream sources:

- `UPSTREAM_CONFIG_*`: fail2ban and Prometheus templates.
- `UPSTREAM_NGINX_*`: Nginx site templates.
- `UPSTREAM_DOCKER_*`: Docker Compose definitions.
- `UPSTREAM_APPS_*`: executable third-party application definitions.
- `UPSTREAM_WEBSITE_SOURCE_*`: site archives and templates.
- `UPSTREAM_*_IMAGE`: `kjlion` container images needed for compatibility.
- `UPSTREAM_PALWORLD_SETTINGS_URL`: a Palworld configuration file that is not
  present in this repository.

`GITHUB_PROXY_BASE` is empty by default. Configuring a proxy explicitly adds
that service to the trust chain; no proxy service is enabled by this fork.

Many additional third-party URLs remain embedded in feature modules. They are
functional dependencies, not reporting endpoints, but remote execution and
pinning risks remain covered by CMD-002, CMD-003, and CMD-013.

## Persistent write locations

The audit found code that writes to all of the following classes of locations:

- Commands: `/usr/local/bin/m`, optional `/usr/bin` links, and legacy `k` paths.
- User files: `~/ming.sh`, legacy links, shell startup files, application
  repositories, OpenClaw configuration, SSH data, and cluster credentials.
- Application data: primarily `/home/docker`, `/home/web`, and `/home/game`.
- System configuration: `/etc/ssh`, `/etc/sudoers.d`, `/etc/sysctl.d`,
  `/etc/security/limits.conf`, package repositories, firewall rules, and
  service definitions.
- Schedulers: the current user's crontab and service enablement through
  systemd or OpenRC.

Centralizing these paths does not make the operations safe; it only makes the
defaults discoverable and future migration reviewable.

## Compatibility consequences

- `m` is the primary command. `k` remains a compatibility link while
  `KEEP_LEGACY_K="true"`.
- Legacy filename wrappers require a neighboring `ming.sh`. Downloading a
  wrapper alone no longer triggers a network fallback.
- `KEEP_LEGACY_PATHS="true"` keeps existing optimizer filenames and markers so
  previous system state remains discoverable.
- Persian and Russian implementations and documentation were removed. Calls to
  those paths now fail instead of silently running an outdated script.
- Project self-update and scheduled auto-update are intentionally unavailable.
  Existing installations may still have old cron entries; administrators must
  inspect and remove those entries manually.

## Validation boundaries

Safe, local checks used for this change:

```bash
bash -n <changed shell files>
shellcheck <changed shell files>
bash tests/tests_project_safety_defaults.sh
bash tests/tests_command_construction_safety.sh
bash tests/tests_openclaw_config_path_resolution_smoke.sh
bash tests_openclaw_manager_smoke.sh
for test_file in tests/openclaw/*.sh; do bash "$test_file"; done
bash cn/tests/openclaw/tests_openclaw_memory_menu_smoke.sh
python3 -m py_compile translate.py en/to-en.py jp/to-jp.py kr/to-kr.py tw/to-tw.py
git diff --check
```

The OpenClaw smoke tests use repository-local temporary directories and command
stubs. In particular, the memory auto-setup harness now restricts `PATH` and
stubs `npm`/`qmd` so it cannot install a real global package during validation.

The following are not part of the safe default run:

- `ming.sh` or any localized main entrypoint.
- `run_openclaw_manager_matrix.sh`, because it runs Docker and can pull images.
- Any test or helper requiring a real service, network, package manager, or
  privileged host path.

## Recommended remediation order

1. Replace remote-script pipelines with download, inspection, pinned digest or
   signature verification, then explicit execution.
2. Remove insecure TLS flags from every executable download.
3. Constrain or remove the intentionally arbitrary tmux background-command
   feature; other reviewed dynamic command paths now use arrays and strict
   allowlists.
4. Add canonical-path guards, mount checks, and explicit confirmations before
   deletion or formatting.
5. Restore SSH host-key verification and replace plaintext password automation
   with keys or an approved secret store.
6. Replace unrestricted sudo rules and world-writable paths with least
   privilege.
7. Isolate all tests under temporary directories or disposable containers
   before enabling them in automation.
