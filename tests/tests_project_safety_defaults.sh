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
	[ "$KEEP_LEGACY_K" = "true" ] || fail "legacy k command must remain enabled"
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

	update_body=$(awk '/^project_update\(\) \{/{found=1} found{print} found && /^}/{exit}' "$script")
	if printf '%s\n' "$update_body" | grep -Eq 'curl|wget|crontab|git (pull|fetch)'; then
		fail "project_update contains a remote or cron operation: $script"
	fi
done

if grep -R -E 'api\.kejilion\.pro|SH_Update_task' "${implementations[@]}"; then
	fail "deprecated telemetry or updater code remains"
fi
if grep -R -i -E '科技[[:space:]]*lion|tech(nology)?[[:space:]]*lion' "${implementations[@]}"; then
	fail "deprecated user-facing branding remains"
fi

wrappers=(
	"$repo_root/kejilion.sh"
	"$repo_root/cn/kejilion.sh"
	"$repo_root/en/kejilion.sh"
	"$repo_root/jp/kejilion.sh"
	"$repo_root/kr/kejilion.sh"
	"$repo_root/tw/kejilion.sh"
)

for wrapper in "${wrappers[@]}"; do
	bash -n "$wrapper"
	grep -Fq 'target="${script_dir}/ming.sh"' "$wrapper" || fail "wrapper target is not local ming.sh: $wrapper"
done

[ ! -e "$repo_root/ir" ] || fail "ir locale should be removed"
[ ! -e "$repo_root/ru" ] || fail "ru locale should be removed"

if grep -R --exclude='tests_project_safety_defaults.sh' -E 'TMPDIR|/tmp/' \
	"$repo_root/tests" \
	"$repo_root/cn/tests" \
	"$repo_root/tests_openclaw_manager_smoke.sh"; then
	fail "safe tests must keep temporary writes inside the repository"
fi

echo "PASS: project safety defaults"
