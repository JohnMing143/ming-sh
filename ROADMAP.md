# Roadmap

Planning date: 2026-07-19. This roadmap continues the remediation order in
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) and the architecture direction in
[`AGENTS.md`](AGENTS.md). Each stage should land as small, independently
validated commits; nothing here authorizes running privileged features during
development.

## Stage 1: stop variant drift at the source

The 2026-07-19 audit found that hand-applied fixes had diverged the six
`ming.sh` copies (missing XanMod end-of-support guard and untranslated
messages in `cn/ming.sh`). The cn copy is now regenerated and pinned by
`tests/tests_variant_sync.sh`; the translated copies are still edited by hand.

1. **Structure-sync check for translated variants.** Add a test that compares
   a normalized code skeleton (string literals and comments stripped) of
   `en|jp|kr|tw/ming.sh` against the root script so functional edits can no
   longer miss a copy silently. Follow the existing extraction-test style;
   no network, no execution.
2. **Regeneration pipeline instead of hand edits.** Extend the `to-*.py`
   tools into a deterministic pipeline: root script + per-language string
   catalog → generated variant. Translation of new strings stays behind
   `ALLOW_REMOTE_TRANSLATION=true`; regeneration from already-translated
   catalogs must work fully offline. Done when a functional change to
   `ming.sh` reaches all variants with one command and no manual editing.
3. **ShellCheck in CI for small files.** Run ShellCheck on helpers and tests
   (the monolithic entrypoints stay excluded for resource reasons, as
   documented in `SECURITY_AUDIT.md`). Fix or annotate findings.

## Stage 2: finish the security remediation backlog

Continue `SECURITY_AUDIT.md` items in order:

4. **Integrity pinning (CMD-002/CMD-013).** Add repository-known SHA-256
   values for remote scripts with stable contents, verified by
   `run_reviewed_remote_script` before execution; for fast-moving upstreams
   (`get.docker.com`), record and display the digest against the last
   reviewed value. Route the retained NodeSource `dnf` pipeline through the
   validator or record a renewed explicit decision.
5. **Shared tagged cron helpers (CMD-012).** `PROJECT_CRON_TAG` exists in
   `config/project.conf` but most cron writers still build their own
   `crontab -l | grep -v` filters. Provide add/remove helpers that tag every
   project-managed entry and migrate the remaining writers (backup jobs,
   certificate renewal, monitoring). The traffic-limit reset job fix
   (CMD-018) is the pattern to follow.
6. **Cluster authentication (CMD-010).** Add an SSH-key path for the cluster
   feature, migrate existing Base64 password stores on first use, and prefer
   pre-provisioned known hosts with `StrictHostKeyChecking=yes` where
   configured.

## Stage 3: shrink the monolith without breaking the install flow

7. **Shared helper library with build-time inlining.**
   `run_reviewed_remote_script` is now duplicated in the entrypoints,
   `mc.sh`, `palworld.sh`, `ldnmp.sh`, and `hermes_manager.sh`. Extract one
   canonical copy under `lib/` and inline it into the shipped standalone
   files with an assemble step plus a sync test (same contract style as
   `tests/tests_variant_sync.sh`). Downloaded files must remain
   self-contained; do not source remote code at runtime.
8. **Module extraction.** Split the root script by feature area (OpenClaw,
   sysctl/network, Docker apps, web stack) into source modules assembled
   into the single released `ming.sh`, keeping the `m` entrypoint and the
   one-file `curl` install unchanged. The OpenClaw block goes first: it is
   self-contained and already has its own smoke suite.

## Stage 4: verification and release hygiene

9. **Isolated Docker matrix (CMD-015).** Run
   `run_openclaw_manager_matrix.sh` in a disposable CI environment on a
   manual trigger or schedule, never in the default push validation.
10. **Release process.** `PROJECT_VERSION` is static at 0.1.0. Define a
    tagging scheme, a change log for this fork (distinct from the archived
    `UPSTREAM_CHANGELOG.txt`), and — before ever enabling
    `ENABLE_SELF_UPDATE` — a signed or digest-pinned update design. Update
    policy stays "disabled" until that design exists.

## Recorded smaller items

- `network-optimize.sh` does not read `config/project.conf` and writes
  `/etc/sysctl.d/99-network-optimize.conf` instead of a project-tagged path;
  its restore action also re-applies the previous optimization backup rather
  than returning to system defaults. Align paths and semantics, with
  migration for the existing file name (READMEs currently document both).
- `ldnmp.sh` substitutes user passwords into `docker-compose.yml` with
  `sed`, which breaks on `/`, `&`, and newline characters; switch to
  delimiter-safe substitution or compose environment variables.
- The traffic accounting in `Limiting_Shut_down1.sh`, `TG-check-notify.sh`,
  and the status views counts only `eth|ens|enp|eno` interfaces, missing
  OpenVZ (`venet0`) and WireGuard-only hosts.
- `auto_cert_renewal.sh` ships a literal `your@email.com`; parameterize it
  at deployment.
- `PandoraNext/` retains upstream example credentials by compatibility
  design (CMD-010); revisit whether generated first-run secrets are possible.
