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

- Project telemetry and usage-reporting code has been removed from every
  localized entrypoint, including the former shell and embedded Python no-op
  compatibility hooks.
- Matrix/Synapse generation explicitly uses `SYNAPSE_REPORT_STATS=no`.
- The former telemetry endpoint and remote user-agreement URL are absent.
- `PROJECT_UPDATE_URL` and `PROJECT_UPDATE_LOG_URL` are empty.
- `project_update` contains no download, cron, Git, or replacement operation.
- Helper-script self-update options only direct users to manual review.
- The scheduled translation workflow, write permission, commit, and push logic
  have been removed.
- Starting a main entrypoint no longer copies the script, edits shell profiles,
  or writes command links. Command installation is an explicit menu action.
- Remote shell installers are downloaded into a private cache, syntax-checked,
  shown with their source path and SHA-256 digest, and denied in non-interactive
  sessions. Execution requires typing the complete digest.

These controls do not disable network access required by an explicitly chosen
ordinary feature, such as downloading a package, querying an API configured by
the user, or pulling an application image.

## Privacy-relevant development tooling

The scheduled translation workflow has been removed. The manual `translate.py`
and locale-specific `to-*.py` tools now refuse to run unless
`ALLOW_REMOTE_TRANSLATION=true` is set explicitly. When enabled, they send
Chinese source-text fragments to Google Translate through `deep_translator`.
This is not telemetry and it is never invoked by the main entrypoint, but the
opt-in can still disclose source text to a third party. Review the input before
enabling remote translation.

## Architecture and trust boundaries

| Component | Role | Trust boundary |
| --- | --- | --- |
| `ming.sh` | Primary monolithic implementation | Runs high-privilege system functions; command-link installation is explicit |
| `cn/en/jp/kr/tw/ming.sh` | Localized implementations | Same risk profile as the root implementation |
| `config/project.conf` | Canonical identity, paths, policy, and upstream sources | Sourced as shell code; only trusted local edits should be used |
| `mc.sh`, `palworld.sh`, `ldnmp.sh`, `hermes_manager.sh` | Standalone feature installers/managers | Perform system writes and execute external tools or installers |
| `tests/` | Static extraction and smoke harnesses | Use temporary homes and command stubs; the Docker matrix remains an explicit exception |

## High-risk command findings

| ID | Risk | Current evidence | Impact | Status |
| --- | --- | --- | --- | --- |
| CMD-001 | Critical: arbitrary command execution | The background-workspace feature now parses direct program arguments and invokes `tmux new-session ... -- "${tmux_command[@]}"` at `ming.sh:3227`; shell metacharacters are no longer interpreted implicitly. | A user can still intentionally launch a shell or another powerful program with the script's privileges. | Mitigated on 2026-07-14. Accidental shell injection is removed; deliberate arbitrary program execution remains an explicit advanced feature. |
| CMD-002 | Critical: remote code is executed without review or integrity verification | `run_reviewed_remote_script` at `ming.sh:181-224` downloads over verified HTTPS, requires `bash -n`, displays the source/cache path/SHA-256, denies non-interactive execution, and requires full-digest confirmation. The identified main, Docker, Hermes, benchmark, panel, reinstall, and helper-script execution paths use this gate. | A compromised mutable upstream can still supply malicious code that a user chooses to approve. | Partially resolved on 2026-07-14. Direct remote-script pipelines and process substitutions are removed; cryptographic pinning remains under CMD-013. |
| CMD-003 | Critical: TLS verification is disabled for executable downloads | No tracked shell file contains `--insecure`, `--no-check-certificate`, or a curl `-k` option; `tests/tests_security_hardening_defaults.sh` enforces the absence. | A network attacker could previously replace executable content without even a valid certificate. | Resolved on 2026-07-14. |
| CMD-004 | High: string-built commands use `eval` | Docker restore now builds `docker_run_args` arrays at `ming.sh:8144`; OpenClaw identity updates use an array at `ming.sh:14949`. | Values that cross quoting boundaries could inject additional shell syntax. | Resolved on 2026-07-14; static regression coverage prevents the former `eval` forms from returning. |
| CMD-005 | Critical: broad deletion and filesystem formatting | Recursive user-selected deletion goes through `safe_remove_path_interactive`; application-data deletions use the same exact-path confirmation. Formatting requires a real unmounted partition with no holders and the exact token `FORMAT /dev/...` (`ming.sh:7182`). Minecraft and Palworld restore now retain the previous container data and validate archive members. | Remaining explicit uninstall and cleanup paths can still destroy the data they name. | Partially resolved on 2026-07-14. Variable/critical paths, formatting, Docker-root migration, and game backups are guarded; remaining feature-specific deletion paths require continued review. |
| CMD-006 | High: SSH host verification is disabled | Main SSH/SCP/rsync paths use the centralized `SSH_STRICT_HOST_KEY_CHECKING=accept-new` policy (`ming.sh:50`, representative use at `ming.sh:6976`); invalid configured values fall back to `yes`, and `beifen.sh` permits only `yes` or `accept-new`. Passwords are passed to `sshpass` through `SSHPASS`, not argv. | First connections still use trust-on-first-use unless administrators configure `yes` and pre-provision known hosts. | Resolved for the verification bypass on 2026-07-14; TOFU remains the compatibility default. |
| CMD-007 | Critical: unrestricted passwordless sudo is written | User sudo rules at `ming.sh:19746` and `ming.sh:20162` now require authentication with `ALL=(ALL:ALL) ALL`. | A sudo-capable account still has broad privilege after authenticating. | Resolved on 2026-07-14; passwordless elevation is no longer created. |
| CMD-008 | High: firewall and network policy can be broadly cleared | `iptables_open` at `ming.sh:974` now refuses the operation. The broad open/close menu paths call the refusal or direct users to per-port controls. `ldnmp.sh` and `auto_cert_renewal-1.sh` no longer flush rules, and the regression test rejects `iptables -F/-X` and `ip6tables -F`. | Explicit per-port, IP, and country-policy features can still change reachability when selected. | Resolved for broad rule flushing on 2026-07-14. |
| CMD-009 | High: world-writable permissions are applied recursively | Recursive `777` uses were replaced with workload-specific `0700`, `0750`, or `0770` modes (for example `ming.sh:15501`, `ming.sh:17234`, and `ming.sh:18317`); Palworld data is owned by its service account. | Incorrect ownership assumptions can still cause availability problems and should be tested per image. | Resolved on 2026-07-14; the regression test rejects recursive `777`. |
| CMD-010 | High: credentials are stored or displayed in plaintext | New cluster entries store an empty password and prompt at connection time; cluster files/directories use `0600`/`0700`, and `sshpass -e` avoids process-list disclosure. `PandoraNext` binds to localhost, disables signup/server tokens, has no setup password, and ships an empty token file. | Some third-party applications still document upstream fixed initial credentials, and administrators must rotate them immediately. | Partially resolved on 2026-07-14. Project-shipped example credentials and new cluster password persistence are removed. |
| CMD-011 | High: startup performs persistent installation writes | Startup now checks a user-state license marker and performs no command installation. `install_project_entrypoint` at `ming.sh:227` is called only by the explicit shortcut menu. | Accepting the license creates a private state marker; explicit installation still writes the selected command paths. | Resolved on 2026-07-14. |
| CMD-012 | High: cron is rewritten in many feature paths | The firewall persistence job now replaces only its project tag (`ming.sh:965`) instead of every `iptables-restore` entry. Minecraft and Palworld backup jobs also use absolute paths and project-specific tags. Other feature and user-command scheduling paths remain. | Incorrect filters can delete unrelated jobs; arbitrary scheduled commands persist with the user's privileges. | Partially resolved on 2026-07-14. Project auto-update cron remains removed; remaining cron writers need migration to shared tagged helpers. |
| CMD-013 | High: dependencies are mutable and usually unpinned | Installers use `latest`, branch heads, short domains, mutable images, and remote application definitions. The remote-script gate exposes and requires confirmation of the fetched SHA-256, but it does not compare against a repository-pinned value. The OpenSSH helper now uses signed distribution packages instead of downloading source tarballs. | A future upstream change can alter behavior without a repository change. | Open. Project-owned and upstream URLs are centralized, but most third-party artifacts and images are not integrity-pinned. |
| CMD-014 | High: command aliases can target arbitrary names under system bin directories | The shortcut menu applies a filename allowlist, rejects consecutive dots, and checks both destination paths before creating links. `install_project_entrypoint` also refuses symlinked home/backup paths and an install link that points anywhere other than the managed home copy. | A crafted or conflicting name could overwrite command paths or create unexpected links. | Resolved on 2026-07-14; existing commands and redirected primary install paths not owned by this project are no longer overwritten. |
| CMD-015 | Medium: test harnesses have unequal isolation | Safe shell tests now use repository-local temporary trees and command stubs; `run_openclaw_manager_matrix.sh:32` still starts Docker containers and may pull images. | Running the Docker matrix can modify Docker state or require network access. | Partially resolved on 2026-07-14. The complete standalone smoke suite is isolated; the Docker matrix remains excluded. |
| CMD-016 | High: generated Docker restore scripts concatenate untrusted metadata | The former generator embedded Compose paths, environment values, volume paths, names, and images directly in shell source. It now uses Bash `printf %q` at `ming.sh:8064`, and the live restore path uses an array at `ming.sh:8144`. | Crafted container metadata or paths could add commands that run later when an administrator executes the generated restore script. | Resolved on 2026-07-14; each generated argument is shell-quoted and the live restore path uses arrays. |
| CMD-017 | High: Matrix/Synapse usage statistics were explicitly enabled | Matrix generation now passes `SYNAPSE_REPORT_STATS=no` at `ming.sh:18075`; `tests/tests_project_safety_defaults.sh:42` rejects the former `yes` setting. | The previous opt-in could disclose Synapse usage metadata to a third party without a project-level privacy choice. | Resolved on 2026-07-14; all localized entrypoints explicitly opt out. |

## Project and upstream remote sources

Project-owned resources use `PROJECT_DOWNLOAD_BASE`, which defaults to the Raw
URL for `JohnMing143/ming-sh`. Ordinary features still depend on explicitly
named upstream sources:

- `UPSTREAM_CONFIG_*`: fail2ban and Prometheus templates.
- `UPSTREAM_NGINX_*`: Nginx site templates.
- `UPSTREAM_DOCKER_*`: Docker Compose definitions.
- `UPSTREAM_APPS_*`: executable third-party application definitions.
- `UPSTREAM_WEBSITE_SOURCE_*`: site archives and templates.
- `UPSTREAM_*_IMAGE`: `kjlion` container images required by upstream-sourced features.
- `UPSTREAM_PALWORLD_SETTINGS_URL`: a Palworld configuration file that is not
  present in this repository.

`GITHUB_PROXY_BASE` is empty by default. Configuring a proxy explicitly adds
that service to the trust chain; no proxy service is enabled by this fork.

Many additional third-party URLs remain embedded in feature modules. They are
functional dependencies, not reporting endpoints, but remote execution and
pinning risks remain covered by CMD-002, CMD-003, and CMD-013.

## Persistent write locations

The audit found code that writes to all of the following classes of locations:

- Commands: `/usr/local/bin/m` and an optional project-configured link, written
  only after the explicit shortcut-install action.
- User files: `~/ming.sh`, shell startup files, application
  repositories, OpenClaw configuration, SSH data, and cluster credentials.
- Application data: primarily `/home/docker`, `/home/web`, and `/home/game`.
- System configuration: `/etc/ssh`, `/etc/sudoers.d`, `/etc/sysctl.d`,
  `/etc/security/limits.conf`, package repositories, firewall rules, and
  service definitions.
- Schedulers: the current user's crontab and service enablement through
  systemd or OpenRC.

Centralizing these paths does not make the operations safe; it only makes the
defaults discoverable and future migration reviewable.

## Naming and migration consequences

- `m` and `ming.sh` are the only default command and entrypoint names.
- New installations use `99-ming-sh-*.conf` optimizer paths and the
  `# ming-sh-optimize` marker.
- Old-brand wrappers, command links, and system-path defaults are no longer
  created by this repository.
- Existing old-brand files, links, optimizer configuration, and cron entries
  are not removed automatically; administrators must review them separately.
- Persian and Russian implementations and documentation were removed. Calls to
  those paths now fail instead of silently running an outdated script.
- Project self-update and scheduled auto-update are intentionally unavailable.
  Existing installations may still have old cron entries; administrators must
  inspect and remove those entries manually.

## Validation boundaries

Safe, local checks used for this change:

```bash
bash -n <changed shell files>
bash tests/tests_project_safety_defaults.sh
bash tests/tests_security_hardening_defaults.sh
bash tests/tests_command_construction_safety.sh
bash tests/tests_openclaw_config_path_resolution_smoke.sh
bash tests/tests_translation_privacy_defaults.sh
bash tests_openclaw_manager_smoke.sh
for test_file in tests/openclaw/*.sh; do bash "$test_file"; done
bash cn/tests/openclaw/tests_openclaw_memory_auto_setup_smoke.sh
bash cn/tests/openclaw/tests_openclaw_memory_menu_smoke.sh
python3 -m py_compile translate.py en/to-en.py jp/to-jp.py kr/to-kr.py tw/to-tw.py
git diff --check
```

ShellCheck is not run on the large monolithic entrypoints because its current
resource usage can exhaust the development environment. It is run on changed
smaller shell files and tests. Main-entrypoint validation uses Bash syntax
checks, targeted static searches, regression tests, and diff review.

The OpenClaw smoke tests use repository-local temporary directories and command
stubs. In particular, the memory auto-setup harness now restricts `PATH` and
stubs `npm`/`qmd` so it cannot install a real global package during validation.

The following are not part of the safe default run:

- `ming.sh` or any localized main entrypoint.
- `run_openclaw_manager_matrix.sh`, because it runs Docker and can pull images.
- Any test or helper requiring a real service, network, package manager, or
  privileged host path.

## Recommended remediation order

1. Pin third-party remote scripts, images, archives, and application
   definitions to reviewed digests or signatures; the review gate is not a
   substitute for a repository-known integrity value.
2. Migrate every remaining cron writer to shared project-tagged add/remove
   helpers and constrain or remove arbitrary scheduled-command input.
3. Continue replacing feature-specific recursive deletion with canonical-path
   guards, exact confirmations, and rollback/backup behavior.
4. Replace password-based cluster and backup automation with SSH keys or an
   approved secret store, and prefer `StrictHostKeyChecking=yes` with
   pre-provisioned known hosts.
5. Replace third-party fixed initial credentials with generated first-run
   secrets where the upstream application permits it.
6. Pin mutable container images and application releases instead of `latest`
   and branch heads.
7. Isolate the Docker matrix in a disposable environment before enabling it in
   automation.
