#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# Roadmap Milestone 1 exit criterion: every tracked file belongs to a known
# category. A new file must be registered here in the matching category and,
# when user- or contributor-facing, documented in the AGENTS.md layout.
# Unexplained files are how unused upstream inheritance accumulated.
unknown=""
while IFS= read -r tracked_file; do
	case "$tracked_file" in
		# Repository metadata and documentation
		.gitattributes|.gitignore|.github/workflows/validate.yml) ;;
		AGENTS.md|README.md|README.en.md|README.tw.md|README.ja.md|README.kr.md|ROADMAP.md) ;;
		SECURITY_AUDIT.md|LICENSE|UPSTREAM_CHANGELOG.txt|apps/README.md) ;;

		# Entrypoints and canonical configuration
		ming.sh|cn/ming.sh|en/ming.sh|jp/ming.sh|kr/ming.sh|tw/ming.sh) ;;
		config/project.conf) ;;

		# Standalone helper scripts deployed or referenced by the entrypoints
		CF-Under-Attack.sh|TG-check-notify.sh|TG-SSH-check-notify.sh) ;;
		Limiting_Shut_down1.sh|beifen.sh|network-optimize.sh) ;;
		auto_cert_renewal.sh|auto_cert_renewal-1.sh|upgrade_openssh9.8p1.sh) ;;
		mc.sh|mc_backup.sh|palworld.sh|pal_backup.sh|hermes_manager.sh) ;;

		# Deployment templates (variant pairs are documented in AGENTS.md)
		www.conf|www-1.conf|custom_mysql_config.cnf|custom_mysql_config-1.cnf) ;;
		optimized_php.ini|sshd.local|fail2ban-nginx-cc.conf|archive.key) ;;

		# Development tooling, shared library sources, translation catalogs
		translate.py|en/catalog.json|jp/catalog.json|kr/catalog.json|tw/catalog.json) ;;
		lib/remote_script.sh|lib/inline.py) ;;

		# Tests
		tests/tests_*.sh|tests/openclaw/tests_*.sh|tests/openclaw/README.md) ;;
		tests/normalize_shell_skeleton.py) ;;
		cn/tests/openclaw/tests_*.sh) ;;
		tests_openclaw_manager_smoke.sh|run_openclaw_manager_matrix.sh) ;;

		*) unknown="${unknown}${tracked_file}"$'\n' ;;
	esac
done < <(git -C "$repo_root" ls-files)

if [ -n "$unknown" ]; then
	printf '%s' "$unknown" >&2
	fail "unregistered tracked files; add them to a category in this test and document them in AGENTS.md"
fi

# Files this fork intentionally removed must stay removed.
removed_paths=(
	"PandoraNext"
	"ldnmp.sh"
	"valkey.conf"
	"cloudflare.conf"
	"nginx.local"
	"Limiting_Shut_down.sh"
	"mc_log.sh"
	"pal_log.sh"
)
for removed_path in "${removed_paths[@]}"; do
	[ ! -e "$repo_root/$removed_path" ] ||
		fail "removed inherited file returned: $removed_path"
done

echo "PASS: repository inventory"
