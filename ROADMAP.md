# Roadmap

Planning date: 2026-07-19 (refined the same day). Goal: a fork one person can
maintain — smaller surface, one source of truth for every artifact, and
conventions enforced by tests instead of memory. This continues the
remediation order in [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) and the
architecture direction in [`AGENTS.md`](AGENTS.md). Work lands as small,
independently validated commits; nothing here authorizes running privileged
features during development.

## Fork posture

This repository is a **hard fork** of the upstream kejilion/sh project
(baseline 4.5.2, archived in
`UPSTREAM_CHANGELOG.txt`). There are no wholesale upstream merges; individual
upstream fixes may be backported after review. Upstream services remain
runtime *content* dependencies (templates, compose files, images) tracked as
`UPSTREAM_*` variables in `config/project.conf` and are subject to the
integrity-pinning milestone. Complexity that exists only because upstream
shipped it — and that this fork does not use — is removed, not maintained.

## Principles

1. **Single source of truth.** Anything that exists in more than one copy is
   generated from one canonical source, never hand-edited (entrypoint
   variants, shared shell helpers, translations).
2. **Smallest maintainable surface.** A file stays only if something
   references it or the maintainer explicitly wants it; every kept file
   appears in the AGENTS.md layout with a purpose.
3. **Mechanical consistency.** Every convention (paths, cron tags, naming,
   generated-file contracts) is enforced by a test that fails in CI, in the
   style of `tests/tests_variant_sync.sh`.

## Milestone 1: prune inherited dead weight — done 2026-07-19

Removed after a reference scan found no functional consumer (each in its own
reviewed commit, with test and audit-document updates):

| Removed | Evidence |
| --- | --- |
| `PandoraNext/` | Referenced only by hardening-test assertions that documented its example credentials (CMD-010); no entrypoint or helper deployed it, and the upstream service is defunct |
| `ldnmp.sh` | The main entrypoints ship their own self-contained LDNMP functions; only tests referenced the standalone file. Its removal also retired its user-input password `sed` weakness (the built-in path generates its own credentials and is delimiter-safe) |
| `valkey.conf`, `cloudflare.conf`, `nginx.local` | Zero references anywhere in the repository |
| `Limiting_Shut_down.sh` | Legacy implementation; deployment fetches `Limiting_Shut_down1.sh` and only reuses this name as the *installed* filename, so the shipped template keeps its suffix |
| `mc_log.sh`, `pal_log.sh` | Display-only changelog echo blocks nothing downloads or sources |

**Exit criterion met:** `tests/tests_repository_inventory.sh` matches every
tracked file against a registered category, keeps the removed files removed,
and fails CI on unregistered additions.

## Milestone 2: one canonical entrypoint source

The audit showed hand-applied edits drift the six `ming.sh` copies apart.
`cn/ming.sh` is already regenerated and pinned by `tests/tests_variant_sync.sh`.

1. **Structure-sync test for `en|jp|kr|tw` — done 2026-07-19.**
   `tests/tests_variant_structure_sync.sh` reduces every implementation to a
   language-neutral code skeleton and requires it to match the root script
   exactly; the structural drift it surfaced (retained APK-cache deletion,
   argument-array construction before image validation, collapsed guard
   formatting) was ported the same day.
2. **Offline regeneration pipeline.** Merge the five near-identical
   translation tools (`translate.py` + four `to-*.py`, ~485 lines for one
   ~110-line program) into a single tool with a language parameter and
   per-language string catalogs. Remote translation of *new* strings stays
   behind `ALLOW_REMOTE_TRANSLATION=true`; regeneration from existing
   catalogs works fully offline.

**Exit criteria:** a functional change is edited in `ming.sh` only and
reaches every variant via one offline command; CI fails if any generated
file was hand-edited.

## Milestone 3: one copy of shared plumbing, one set of conventions

3. **Shared helper library with build-time inlining.**
   `run_reviewed_remote_script` currently exists in 9 copies (6 entrypoints,
   `mc.sh`, `palworld.sh`, `hermes_manager.sh`).
   Keep one canonical copy under `lib/`, inline it into shipped standalone
   files with an assemble step, and pin the result with a sync test. Shipped
   files stay self-contained; no runtime sourcing of remote code.
4. **Tagged cron helpers (CMD-012).** `PROJECT_CRON_TAG` exists but most cron
   writers still build ad-hoc `crontab -l | grep -v` filters. Provide shared
   add/remove helpers that tag every project-managed entry and migrate the
   remaining writers; the CMD-018 exact-format filter is the interim pattern.
5. **One sysctl path convention.** Align `network-optimize.sh` with
   `config/project.conf` (project-tagged config path, marker comment) with
   migration for the existing `99-network-optimize.conf` name, and make its
   restore action return to system defaults instead of re-applying the
   previous optimization backup.
6. **ShellCheck in CI** for helpers and tests (the monolithic entrypoints
   stay excluded for the resource reasons documented in the audit).
7. **Documentation language policy, stated in AGENTS.md:** user-facing
   READMEs in zh/tw/ja/kr maintained together; developer docs (AGENTS,
   SECURITY_AUDIT, ROADMAP) in English only. Resolve the current mismatch:
   `en/ming.sh` ships without an English README — either add `README.en.md`
   to the maintained set or record that the English variant is documented
   through the existing READMEs.

**Exit criteria:** grep finds exactly one definition of each shared helper in
source form; every convention above has a failing-test guard.

## Milestone 4: remaining security backlog (on the smaller surface)

8. **Integrity pinning (CMD-002/CMD-013).** Repository-known SHA-256 values
   for stable remote scripts, verified by `run_reviewed_remote_script` before
   execution (one place to change after Milestone 3); recorded-digest display
   for fast-moving upstreams like `get.docker.com`. Route the retained
   NodeSource `dnf` pipeline through the validator or record a renewed
   explicit maintainer decision.
9. **Cluster authentication (CMD-010).** SSH-key path for the cluster
   feature, migration for the Base64 password store, and support for
   pre-provisioned known hosts with `StrictHostKeyChecking=yes`.

## Milestone 5: modularize behind the stable entrypoint

Only after Milestones 1–3 provide guardrails: split the root script by
feature area (OpenClaw first — self-contained with its own smoke suite; then
sysctl/network, Docker apps, web stack) into source modules assembled into
the single released `ming.sh`. The `m` command and one-file `curl` install
never change. Alongside: run the Docker matrix (CMD-015) in a disposable CI
environment on manual trigger only, and define a release process — tagging,
a fork change log, and (before ever enabling `ENABLE_SELF_UPDATE`) a signed
or digest-pinned update design. Updates stay disabled until that design
exists.

## Standing rules during consolidation

- No new features until Milestone 3 is complete.
- Never hand-edit a generated file; regenerate it.
- Recorded low-priority items: traffic accounting in
  `Limiting_Shut_down1.sh` / `TG-check-notify.sh` counts only
  `eth|ens|enp|eno` interfaces (misses OpenVZ `venet0` and WireGuard-only
  hosts); `auto_cert_renewal.sh` ships a literal `your@email.com` that should
  be parameterized at deployment.
