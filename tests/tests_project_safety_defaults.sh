#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

(
	# shellcheck disable=SC1091
	. "$repo_root/config/project.conf"
	[ "$PROJECT_NAME" = "ming.sh" ] || fail "unexpected project name"
	[ "$PROJECT_COMMAND" = "m" ] || fail "unexpected primary command"
	[ "$PROJECT_REPO" = "JohnMing143/ming-sh" ] || fail "unexpected repository"
	[ "$ENABLE_SELF_UPDATE" = "false" ] || fail "self-update must default to false"
	[ "$ENABLE_AUTO_UPDATE" = "false" ] || fail "automatic update must default to false"
	[ -z "$PROJECT_UPDATE_URL" ] || fail "update URL must be empty"
	[ "$PROJECT_BBR_CONFIG_PATH" = "/etc/sysctl.d/99-ming-sh-bbr.conf" ] || fail "unexpected BBR config path"
	[ "$PROJECT_OPTIMIZE_CONFIG_PATH" = "/etc/sysctl.d/99-ming-sh-optimize.conf" ] || fail "unexpected optimizer config path"
	[ "$PROJECT_OPTIMIZE_MARKER" = "# ming-sh-optimize" ] || fail "unexpected optimizer marker"
)

implementations=(
	"$repo_root/ming.sh"
	"$repo_root/cn/ming.sh"
	"$repo_root/en/ming.sh"
	"$repo_root/jp/ming.sh"
	"$repo_root/kr/ming.sh"
	"$repo_root/tw/ming.sh"
)

for script in "${implementations[@]}"; do
	[ -f "$script" ] || fail "missing implementation: $script"
	bash -n "$script"

	if grep -Eq 'send_stats|send_stat\(|ENABLE_(TELEMETRY|STATS)|TELEMETRY_ENDPOINT' "$script"; then
		fail "removed project telemetry code returned: $script"
	fi
	if grep -Fq 'SYNAPSE_REPORT_STATS=yes' "$script"; then
		fail "Matrix/Synapse statistics reporting is enabled: $script"
	fi
	grep -Fq 'SYNAPSE_REPORT_STATS=no' "$script" || fail "Matrix/Synapse reporting opt-out is missing: $script"
	deprecated_compat_pattern='KEEP_''LEGACY|LEGACY_(COMMAND|SCRIPT|HOME|BACKUP|INSTALL|LINK|BBR|OPTIMIZE)|ACTIVE_(BBR|OPTIMIZE)|gl_''kjlan'
	if grep -Eq "$deprecated_compat_pattern" "$script"; then
		fail "deprecated project naming compatibility remains: $script"
	fi

	update_body=$(awk '/^project_update\(\) \{/{found=1} found{print} found && /^}/{exit}' "$script")
	if printf '%s\n' "$update_body" | grep -Eq 'curl|wget|crontab|git (pull|fetch)'; then
		fail "project_update contains a remote or cron operation: $script"
	fi
done

deprecated_vendor='keji''lion'
if grep -R -E "api\\.${deprecated_vendor}\\.pro|SH_Update_task" "${implementations[@]}"; then
	fail "deprecated telemetry or updater code remains"
fi
if grep -R -i -E '科技[[:space:]]*lion|tech(nology)?[[:space:]]*lion' "${implementations[@]}"; then
	fail "deprecated user-facing branding remains"
fi

deprecated_image_namespace='kj''lion'
branding_pattern="${deprecated_vendor}|${deprecated_image_namespace}|科技[[:space:]]*lion|tech(nology)?[[:space:]]*lion"
branding_matches=$(grep -R -n -i -E "$branding_pattern" \
	--exclude-dir=.git \
	--exclude='*.pyc' \
	--exclude=LICENSE \
	--exclude=UPSTREAM_CHANGELOG.txt \
	"$repo_root" || true)
while IFS=: read -r match_file _ match_text; do
	[ -n "$match_file" ] || continue
	case "$match_file" in
		"$repo_root/AGENTS.md"|"$repo_root/README.md"|"$repo_root/README.en.md"|"$repo_root/README.tw.md"|"$repo_root/README.ja.md"|"$repo_root/README.kr.md"|"$repo_root/ROADMAP.md"|"$repo_root/network-optimize.sh"|"$repo_root/apps/README.md")
			printf '%s\n' "$match_text" | grep -Eqi 'upstream|derived|Apache|github\.com' || fail "unexpected branding context: $match_file"
			;;
		"$repo_root/config/project.conf"|"$repo_root/ming.sh"|"$repo_root/cn/ming.sh"|"$repo_root/en/ming.sh"|"$repo_root/jp/ming.sh"|"$repo_root/kr/ming.sh"|"$repo_root/tw/ming.sh"|"$repo_root/palworld.sh"|"$repo_root/SECURITY_AUDIT.md")
			printf '%s\n' "$match_text" | grep -Fqi 'UPSTREAM' || fail "old branding is not isolated as an upstream dependency: $match_file"
			;;
		*) fail "unexpected old-brand match: $match_file" ;;
	esac
done <<EOF
$branding_matches
EOF

deprecated_entrypoint="${deprecated_vendor}.sh"
for locale in '' cn en jp kr tw; do
	wrapper="$repo_root/${locale:+$locale/}$deprecated_entrypoint"
	[ ! -e "$wrapper" ] || fail "deprecated entrypoint remains: $wrapper"
done

helpers=("$repo_root/mc.sh" "$repo_root/palworld.sh")
if grep -E 'm\|k\)|k 兼容|兼容 k' "${helpers[@]}"; then
	fail "deprecated command compatibility remains in helper menus"
fi

[ ! -e "$repo_root/ir" ] || fail "ir locale should be removed"
[ ! -e "$repo_root/ru" ] || fail "ru locale should be removed"

if grep -R --exclude='tests_project_safety_defaults.sh' -E 'TMPDIR|/tmp/' \
	"$repo_root/tests" \
	"$repo_root/cn/tests" \
	"$repo_root/tests_openclaw_manager_smoke.sh"; then
	fail "safe tests must keep temporary writes inside the repository"
fi

echo "PASS: project safety defaults"
