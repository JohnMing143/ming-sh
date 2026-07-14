# Security Audit

## Scope

This is an incremental audit. The first pass covers privacy reporting and the
high-risk commands encountered while tracing that behavior. It is not a
complete security review of the project.

The localized `kejilion.sh` copies generally repeat the same command patterns.
Line references below use the root `kejilion.sh` unless another file is named.

## Step 1 result

- Usage statistics are disabled by default in every shipped language entry
  point.
- Statistics are sent only when `ENABLE_STATS` is explicitly set to `true`.
- No new endpoint or remote service was added.

## Open high-risk command findings

| ID | Risk | Evidence | Impact | Status |
| --- | --- | --- | --- | --- |
| CMD-001 | Critical | `kejilion.sh:507` executes the contents of `$dockername` as a command after interactive input. `kejilion.sh:19616-19617` similarly accepts an arbitrary command for a background tmux session. | Anyone controlling the input can execute arbitrary commands with the script's privileges. | Recorded; not changed in step 1. |
| CMD-002 | Critical | Remote scripts are executed directly, for example `kejilion.sh:6451`, `kejilion.sh:7933`, `hermes_manager.sh:964`, `ldnmp.sh:15`, `mc.sh:92`, and `palworld.sh:79`. | A compromised host, DNS path, proxy, or upstream script can become immediate code execution, commonly as root. | Recorded; not changed in step 1. |
| CMD-003 | Critical | TLS verification is disabled while downloading executable code at `kejilion.sh:16415`, `kejilion.sh:16426`, `kejilion.sh:16908`, and `kejilion.sh:17951`. | A network attacker can replace installer content before it is executed. | Recorded; not changed in step 1. |
| CMD-004 | High | String-built commands are passed to `eval` at `kejilion.sh:8305` and `kejilion.sh:15277`. | Insufficiently validated values can break command boundaries and inject additional shell syntax. | Recorded; not changed in step 1. |
| CMD-005 | High | Destructive deletion includes user-selected paths (`kejilion.sh:21351`) and broad fixed paths such as `/home/docker` (`kejilion.sh:2837`) and `/tmp/*` (`kejilion.sh:4742`). Standalone backup scripts also use `rm -rf`, for example `mc_backup.sh:6` and `pal_backup.sh:6`. | A wrong, empty, or manipulated path can cause irreversible data loss. | Recorded; not changed in step 1. |
| CMD-006 | High | The updater accepts a downloaded script after checking only that its first line is `#!/bin/bash` (`kejilion.sh:21813`, `kejilion.sh:21853`). | The check confirms file shape, not authenticity or integrity; a substituted payload can be installed and later executed. | Recorded; not changed in step 1. |
| CMD-007 | High | SSH/SCP calls disable host-key verification, including `kejilion.sh:7069`, `kejilion.sh:8343`, and `kejilion.sh:21461`. | Connections are vulnerable to machine-in-the-middle interception and credential or file theft. | Recorded; not changed in step 1. |
| CMD-008 | High | Passwordless unrestricted sudo rules are written at `kejilion.sh:20118` and `kejilion.sh:20532`. | Compromise of the affected account becomes immediate unrestricted root access. | Recorded; not changed in step 1. |

## Suggested order for later passes

1. Replace remote-script pipelines with download, pinned integrity verification,
   inspection, and explicit execution.
2. Remove `--insecure`/`-k` from executable downloads.
3. Replace arbitrary command execution and `eval` with argument arrays and
   strict allowlists.
4. Add path guards and confirmations around destructive deletion.
5. Restore SSH host-key verification and narrow sudo privileges.
