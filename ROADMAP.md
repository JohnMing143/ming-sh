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
4. **Proportion over defense.** Match the solution to the actual risk. Prefer
   the simplest thing that works, guarded by one load-bearing test; do not add
   parameters, layers, or overlapping checks for hypothetical cases. One
   direct guard beats several redundant ones. This applies to the plan itself:
   avoid overthinking that produces over-engineered, defensive scaffolding.

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
2. **Offline regeneration pipeline — done 2026-07-19.** The five translation
   tools are merged into `translate.py` with offline `harvest`/`generate`/
   `check`/`status` subcommands and per-line catalogs (`<lang>/catalog.json`,
   ~2,800 entries per language, byte-exact roundtrip). Only the
   `translate-missing` subcommand contacts Google Translate, still behind
   `ALLOW_REMOTE_TRANSLATION=true`.

**Exit criteria met:** a functional change is edited in `ming.sh` only and
`python3 translate.py generate --all` reaches every variant offline;
`tests/tests_variant_generation_sync.sh` fails CI if a generated file was
hand-edited or regeneration was skipped.

## Milestone 3: one copy of shared plumbing, one set of conventions — done 2026-07-19

3. **Shared helper library with build-time inlining — done 2026-07-19.**
   `run_reviewed_remote_script` (formerly 9 copies: 6 entrypoints, `mc.sh`,
   `palworld.sh`, `hermes_manager.sh`) now has one source in
   `lib/remote_script.sh`, inlined between generation markers by
   `lib/inline.py`. Shipped files stay self-contained; nothing sources the
   library at runtime. `tests/tests_shared_lib_sync.sh` pins every copy.
4. **Tagged cron helpers (CMD-012) — done 2026-07-19.** Added
   `cron_install_tagged`/`cron_remove_tagged` and migrated the co-located
   project-managed writers (logrotate, certificate renewal, TG monitor),
   removing their broad `grep -v` filters. The remove-only FRP and OpenClaw
   gateway broad filters are intentionally left in place until their add sites
   are identified (still tracked under CMD-012); `tests/tests_cron_tagging.sh`
   guards the migrated writers.
5. **One sysctl path convention — done 2026-07-19.** `network-optimize.sh`
   now writes `/etc/sysctl.d/99-ming-sh-network.conf` with a
   `# ming-sh-network-optimize` marker, auto-migrates the legacy
   `99-network-optimize.conf` name on run and restore, and its restore action
   removes the config and reloads system defaults instead of re-applying a
   prior optimization backup. The entrypoints detect and clean both paths;
   `tests/tests_network_optimize_paths.sh` guards it.
6. **ShellCheck in CI — done 2026-07-19.** The workflow runs ShellCheck at
   error severity on every tracked shell file except the six entrypoints
   (excluded for the documented resource reasons). Tightening the severity
   gate toward warning level, after triaging the legacy helpers in a
   ShellCheck-capable environment, is future work.
7. **Documentation language policy — done 2026-07-19.** Stated in AGENTS.md:
   user-facing READMEs are maintained together, one per shipped locale
   (zh/en/tw/ja/kr) with cross-linked selectors; developer docs and tooling
   comments are English only. The missing `README.en.md` for the shipped
   English entrypoint was added and cross-linked.

**Exit criteria met (2026-07-19):** the remote-script validator has one
editable source (`lib/remote_script.sh`), and `lib/inline.py --check` proves
every shipped copy matches it; each convention above has a failing-test guard
(`tests_shared_lib_sync.sh`, `tests_cron_tagging.sh`,
`tests_network_optimize_paths.sh`, the CI ShellCheck step, and the inventory
allowlist).

## Milestone 4: remaining security backlog (on the smaller surface) — done 2026-07-19

8. **Integrity pinning (CMD-002/CMD-013) — reassessed 2026-07-19.** A review
   of the whole remote-script surface (19 URLs) found script-level pinning
   does not apply: 14 target third-party moving refs (`latest`/branch heads)
   and 5 interpolate the proxy-dependent project base, so there is no stable
   digest to pin — building a pin registry here would be machinery for a case
   that does not exist. The NodeSource `dnf` exception was re-affirmed as a
   documented, allowlisted convenience. The applicable integrity work is
   pinning container **images** and application **releases** to digests (a
   separate mechanism from the script validator); that is the remaining
   CMD-013 item. Transport (TLS), syntax check, and digest display stay as-is.
9. **Cluster authentication (CMD-010) — done 2026-07-19.** The cluster
   feature now supports SSH-key auth: a blank add-server password stores the
   credential `key` (or a hand-set `key:/path`), and `run_commands_on_servers`
   connects with `ssh` using the default key/agent or identity file, storing
   no password. Existing Base64 password entries are unchanged (backward
   compatible), and host verification still follows the centralized
   `SSH_STRICT_HOST_KEY_CHECKING` policy, which an administrator can set to
   `yes` with pre-provisioned known hosts. `tests/tests_security_hardening_defaults.sh`
   covers both the key and password paths.

## Milestone 5: modularize behind the stable entrypoint

**Docker matrix isolation (CMD-015) — done 2026-07-19.** The
`run_openclaw_manager_matrix.sh` matrix now runs only through
`.github/workflows/docker-matrix.yml`, a `workflow_dispatch`-only workflow in
a disposable runner; it never runs on the developer host or in default
validation.

**Source modularization — reassessed 2026-07-19, recommended to defer.** The
premise "OpenClaw is self-contained, extract it first" holds: OpenClaw is a
contiguous ~5,350-line block (`ming.sh` 10039–15389) with its own smoke suite,
so a clean cut is feasible using the proven `lib/inline.py` inline-marker
pattern, and byte-identical assembly would leave the catalogs and variants
untouched. But the cost/benefit does not favor doing it now:

- The shipped `ming.sh` is unchanged (the module is inlined back), so the only
  benefit is editing a 5k-line file instead of a region of the 21k-line file.
- It adds a third build stage (`modules → ming.sh`) on top of the existing
  `lib → ming.sh` inline and `ming.sh → variants` generation. For a solo
  maintainer, that build-pipeline complexity works against the "one person can
  maintain" goal — the same goal modularization is meant to serve.
- The generation pipeline already makes `ming.sh` the single source, so the
  maintainability problem modularization targets is partly already solved.

Recommendation: defer until the monolith's size is a concrete, felt pain
point, then extract only OpenClaw (the largest, smoke-tested block) via the
existing inline pattern — one module, not a framework. This is a maintainer
decision, not a blocker.

**Release process — deferred as premature.** With no release cadence yet and
project updates deliberately disabled (`ENABLE_SELF_UPDATE=false`), building
tagging/changelog machinery now would be process for its own sake. When
releases begin: annotated tags, a fork change log distinct from the archived
`UPSTREAM_CHANGELOG.txt`, and — only before ever enabling self-update — a
signed or digest-pinned update design. Updates stay disabled until then.

## Standing rules

- Milestones 1–4 are complete; Milestone 5's Docker-matrix isolation is done
  and its source-modularization is deferred by recommendation (a maintainer
  decision, not a blocker). The open security item is container-image/release
  digest pinning (the applicable remainder of CMD-013). Prefer these over new
  features.
- Never hand-edit a generated file; regenerate it. After editing `ming.sh` run
  `python3 translate.py generate --all`; after editing anything in `lib/` run
  `python3 lib/inline.py` (then regenerate if `ming.sh` changed).
- Recorded low-priority items: traffic accounting in
  `Limiting_Shut_down1.sh` / `TG-check-notify.sh` counts only
  `eth|ens|enp|eno` interfaces (misses OpenVZ `venet0` and WireGuard-only
  hosts); `auto_cert_renewal.sh` ships a literal `your@email.com` that should
  be parameterized at deployment; the remove-only FRP (`grep -v 'frps'`/
  `'frpc'`) and OpenClaw gateway (`grep -v "s gateway"`) crontab filters
  still need their add sites identified before they can be retagged (CMD-012).
