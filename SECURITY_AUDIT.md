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
- Starting a main entrypoint uses the guarded installer to keep the stable `m`
  command available automatically. It does not edit shell profiles, and path or
  symlink conflicts make installation fail nonfatally without blocking menus.
- Remote shell installers are downloaded over verified HTTPS into a private
  cache, Bash syntax-checked, logged with their source and SHA-256 digest where
  available, executed automatically, and then removed. No additional approval
  prompt is inserted into the selected feature workflow.

These controls do not disable network access required by an explicitly chosen
ordinary feature, such as downloading a package, querying an API configured by
the user, or pulling an application image.

## Privacy-relevant development tooling

The scheduled translation workflow has been removed. Since 2026-07-19 the
localized variants are regenerated offline by `translate.py` from the root
script and per-language `<lang>/catalog.json` translation catalogs; the
`harvest`, `generate`, `check`, and `status` subcommands never contact the
network. Only the `translate-missing` subcommand sends Chinese source-text
fragments to Google Translate through `deep_translator`, and it refuses to
run unless `ALLOW_REMOTE_TRANSLATION=true` is set explicitly. This is not
telemetry and it is never invoked by the main entrypoint, but the opt-in can
still disclose source text to a third party. Review the input before enabling
remote translation.

## Architecture and trust boundaries

| Component | Role | Trust boundary |
| --- | --- | --- |
| `ming.sh` | Primary monolithic implementation | Runs high-privilege system functions; guarded command installation occurs automatically |
| `cn/en/jp/kr/tw/ming.sh` | Localized implementations | Same risk profile as the root implementation |
| `config/project.conf` | Canonical identity, paths, policy, and upstream sources | Sourced as shell code; only trusted local edits should be used |
| `mc.sh`, `palworld.sh`, `hermes_manager.sh` | Standalone feature installers/managers | Perform system writes and execute external tools or installers |
| `tests/` | Static extraction and smoke harnesses | Use temporary homes and command stubs; the Docker matrix remains an explicit exception |

## High-risk command findings

| ID | Risk | Current evidence | Impact | Status |
| --- | --- | --- | --- | --- |
| CMD-001 | Critical: arbitrary command execution | The background-workspace feature now parses direct program arguments and invokes `tmux new-session ... -- "${tmux_command[@]}"` at `ming.sh:3227`; shell metacharacters are no longer interpreted implicitly. | A user can still intentionally launch a shell or another powerful program with the script's privileges. | Mitigated on 2026-07-14. Accidental shell injection is removed; deliberate arbitrary program execution remains an explicit advanced feature. |
| CMD-002 | Critical: remote code is executed without repository-known integrity verification | `run_reviewed_remote_script` downloads over verified HTTPS into a private file, requires `bash -n`, records the source and SHA-256 where available, executes with an argument array, and removes the file afterward. The identified main, Docker, Hermes, benchmark, panel, reinstall, and helper-script execution paths use this automatic validator. One exception is retained by explicit maintainer decision: the `dnf` branch of `install_node_and_tools` pipes `https://rpm.nodesource.com/setup_24.x` directly to `sudo bash` for convenience (`ming.sh:10121` and all localized copies). `tests/tests_security_hardening_defaults.sh` allowlists exactly this source and forbids any other remote pipeline, including `sudo` variants. | A compromised mutable upstream can still supply malicious code that is executed immediately when the user selects the feature. Bash syntax validation is not a trust decision. The retained NodeSource pipeline additionally skips the validator's syntax check, digest logging, and private-cache handling. | Mitigated on 2026-07-14 for transport, temporary-file, and command-construction risks. The NodeSource pipeline is open by explicit convenience design on 2026-07-14. Integrity pinning remains open under CMD-013; no extra confirmation is imposed for compatibility. |
| CMD-003 | Critical: TLS verification is disabled for executable downloads | No tracked shell file contains `--insecure`, `--no-check-certificate`, or a curl `-k` option; `tests/tests_security_hardening_defaults.sh` enforces the absence. | A network attacker could previously replace executable content without even a valid certificate. | Resolved on 2026-07-14. |
| CMD-004 | High: string-built commands use `eval` | Docker restore now builds `docker_run_args` arrays at `ming.sh:8144`; OpenClaw identity updates use an array at `ming.sh:14949`. | Values that cross quoting boundaries could inject additional shell syntax. | Resolved on 2026-07-14; static regression coverage prevents the former `eval` forms from returning. |
| CMD-005 | Critical: broad deletion and filesystem formatting | Recursive deletion goes through noninteractive `safe_remove_path`, which canonicalizes the parent and rejects empty, ambiguous, root, and critical system paths. Existing menu selections remain the only interaction. Formatting requires a validated `/dev/<partition>`, `lsblk TYPE=part`, no mount, no holders, an allowed filesystem, and the original single y/n confirmation. Minecraft and Palworld restore retain the previous container data and validate archive members. | An explicitly selected valid application path or partition can still be destroyed, and the canonical guard cannot provide rollback. | Mitigated on 2026-07-14 without duplicate confirmations. Variable/critical paths, formatting targets, Docker-root migration, and game backups are guarded; feature-specific destructive operations remain open by design. |
| CMD-006 | High: SSH host verification is disabled | Main SSH/SCP/rsync paths use the centralized `SSH_STRICT_HOST_KEY_CHECKING=accept-new` policy (`ming.sh:50`, representative use at `ming.sh:6976`); invalid configured values fall back to `yes`, and `beifen.sh` permits only `yes` or `accept-new`. Passwords are passed to `sshpass` through `SSHPASS`, not argv. | First connections still use trust-on-first-use unless administrators configure `yes` and pre-provision known hosts. | Resolved for the verification bypass on 2026-07-14; TOFU remains the compatibility default. |
| CMD-007 | Critical: unrestricted passwordless sudo is written | The explicitly selected highest-privilege SSH-key user and user-manager sudo action write `ALL=(ALL) NOPASSWD:ALL` in a dedicated `0440` sudoers file. This preserves usability for password-locked key-only accounts. | Compromise of that selected account provides immediate root-equivalent execution without another authentication factor. | Open by explicit compatibility design on 2026-07-14. Scope is limited to administrator-selected privilege features; silent or default user creation does not receive the rule. |
| CMD-008 | High: firewall and network policy can be broadly cleared | `iptables_open` and the advanced open/close-all actions are functional again. They automatically save timestamped IPv4/IPv6 backups under `/etc/iptables/backups`, then apply and persist the selected broad policy. `auto_cert_renewal-1.sh` does not flush unrelated firewall state (the standalone `ldnmp.sh`, formerly also checked here, was removed as unused on 2026-07-19). | Selecting open-all exposes every listening service; selecting close-all can still disrupt access despite preserving the detected SSH port and established connections. | Mitigated/open by explicit feature design on 2026-07-14. Automatic backup adds recovery material without adding a prompt; broad policy changes remain intentionally available. |
| CMD-009 | High: world-writable permissions are applied recursively | Recursive `777` uses remain replaced with workload-specific ownership and modes. OpenList and Jellyfin run as root with `0750`; n8n and 2FAuth data are owned by UID/GID 1000 with `0700`; Palworld data is owned by its service account. Compatibility-sensitive Cloudreve/aria2 and DSM paths retain restricted group-writable modes. | Future image UID changes can still cause availability problems and should be checked when images change. | Mitigated on 2026-07-14; known container users retain write access without restoring blanket `777`. |
| CMD-010 | High: credentials are stored or displayed in plaintext | Cluster passwords are captured once, stored as reversible Base64 in `servers.py` for automation, protected by directory/file modes `0700`/`0600`, decoded only for `SSHPASS=... sshpass -e`, and not placed in argv. The PandoraNext example configuration that shipped upstream example setup/token credentials was removed on 2026-07-19 as unused; no entrypoint or helper deployed it. | Base64 is not encryption; anyone who can read the cluster file can recover passwords. | Open by compatibility design on 2026-07-14 for cluster storage. File permissions and process-list handling are mitigations, not secret storage; administrators should migrate clusters to SSH keys. |
| CMD-011 | High: startup performs persistent installation writes | Startup migrates a recognized legacy `permission_granted=true` agreement into the private state marker, then automatically invokes guarded `install_project_entrypoint` so `m` remains available without another setup action. Symlink and non-project file conflicts are rejected, shell profiles are not edited, and installation failure is nonfatal. | Successful startup can copy the script to `~/ming.sh` and `/usr/local/bin/m`, replacing only files recognized as this project. | Mitigated/open by compatibility design on 2026-07-14. Automatic command availability and prior agreement state are restored while redirected/conflicting paths and failure propagation are controlled. |
| CMD-012 | High: cron is rewritten in many feature paths | Shared `cron_install_tagged`/`cron_remove_tagged` helpers now tag every entry they manage with `# ming-sh:<name>` and remove by that exact tag. The firewall persistence, rsync, and traffic-limit reset jobs were already tagged/exact; the logrotate, certificate-renewal, and TG-monitor writers were migrated on 2026-07-19, removing their broad `grep -v 'logrotate'` and `grep -v '~/TG-check-notify.sh'` filters. `tests/tests_cron_tagging.sh` enforces the helpers and forbids the removed filters. Still open: the FRP (`grep -v 'frps'`/`'frpc'`) and OpenClaw gateway (`grep -v "s gateway"`) removals are broad-word filters whose matching add sites are not co-located, so they cannot be retagged without first identifying what installs them; the fail2ban-uninstall `CF-Under-Attack.sh` filter is filename-specific and low risk; the custom-command feature filters a user-supplied keyword by design. | Incorrect filters can delete unrelated jobs; arbitrary scheduled commands persist with the user's privileges. Existing installations may still carry untagged entries, which are manual cleanup per project policy. | Partially resolved; project-managed writers with co-located add/remove now use tagged helpers. Remaining broad-word FRP/gateway filters and arbitrary user scheduling are open. |
| CMD-013 | High: dependencies are mutable and usually unpinned | Installers use `latest`, branch heads, short domains, mutable images, and remote application definitions. The remote-script validator can log the fetched SHA-256 but does not compare it with a repository-pinned value before automatic execution. The OpenSSH helper uses signed distribution packages instead of downloading source tarballs. | A future upstream change can alter behavior without a repository change and can execute as soon as its feature is selected. | Open. Project-owned and upstream URLs are centralized, but most third-party artifacts and images are not integrity-pinned. |
| CMD-014 | High: command aliases can target arbitrary names under system bin directories | The shortcut menu applies a filename allowlist, rejects consecutive dots, and checks both destination paths before creating links. `install_project_entrypoint` also refuses symlinked home/backup paths and an install link that points anywhere other than the managed home copy. | A crafted or conflicting name could overwrite command paths or create unexpected links. | Resolved on 2026-07-14; existing commands and redirected primary install paths not owned by this project are no longer overwritten. |
| CMD-015 | Medium: test harnesses have unequal isolation | Safe shell tests now use repository-local temporary trees and command stubs; `run_openclaw_manager_matrix.sh:32` still starts Docker containers and may pull images. | Running the Docker matrix can modify Docker state or require network access. | Partially resolved on 2026-07-14. The complete standalone smoke suite is isolated; the Docker matrix remains excluded. |
| CMD-016 | High: generated Docker restore scripts concatenate untrusted metadata | The former generator embedded Compose paths, environment values, volume paths, names, and images directly in shell source. It now uses Bash `printf %q` at `ming.sh:8064`, and the live restore path uses an array at `ming.sh:8144`. | Crafted container metadata or paths could add commands that run later when an administrator executes the generated restore script. | Resolved on 2026-07-14; each generated argument is shell-quoted and the live restore path uses arrays. |
| CMD-017 | High: Matrix/Synapse usage statistics were explicitly enabled | Matrix generation now passes `SYNAPSE_REPORT_STATS=no` at `ming.sh:18075`; `tests/tests_project_safety_defaults.sh:42` rejects the former `yes` setting. | The previous opt-in could disclose Synapse usage metadata to a third party without a project-level privacy choice. | Resolved on 2026-07-14; all localized entrypoints explicitly opt out. |
| CMD-018 | High: the traffic-limit shutdown deployer trusted raw input and filtered cron too broadly | Threshold and reset-day input is normalized to the documented numeric defaults before use (`ming.sh:20657`), the deployed template is edited with substitutions anchored to the exact `rx_threshold_gb=110`/`tx_threshold_gb=120` assignment lines, and the reset job is removed with an exact-format filter instead of `grep -v 'reboot'`. `tests/tests_command_construction_safety.sh` rejects the former unanchored and broad-filter forms. | Previously a non-numeric threshold entry was substituted into a root cron script where it could evaluate to 0 and trigger an immediate shutdown, an rx value of 120 was clobbered by the tx substitution, and enabling or disabling the feature deleted every crontab line containing "reboot", including the TG monitor's `@reboot` entry. | Resolved on 2026-07-19 in every implementation. Localized copies formerly drifted apart during hand-applied fixes; `tests/tests_variant_sync.sh` now pins the cn copy to the root entrypoint byte-for-byte. |

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
  automatically by the guarded startup installer and by shortcut management.
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
python3 -m py_compile translate.py tests/normalize_shell_skeleton.py
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
   definitions to reviewed digests or signatures; HTTPS and syntax validation
   are not substitutes for a repository-known integrity value.
2. Migrate every remaining cron writer to shared project-tagged add/remove
   helpers and constrain or remove arbitrary scheduled-command input.
3. Continue replacing feature-specific recursive deletion with canonical-path
   guards and practical rollback/backup behavior without duplicating existing
   feature confirmations.
4. Replace password-based cluster and backup automation with SSH keys or an
   approved secret store, and prefer `StrictHostKeyChecking=yes` with
   pre-provisioned known hosts.
5. Replace third-party fixed initial credentials with generated first-run
   secrets where the upstream application permits it.
6. Pin mutable container images and application releases instead of `latest`
   and branch heads.
7. Isolate the Docker matrix in a disposable environment before enabling it in
   automation.
