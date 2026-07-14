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
	[ "$ENABLE_TELEMETRY" = "false" ] || fail "telemetry must default to false"
	[ "$ENABLE_SELF_UPDATE" = "false" ] || fail "self-update must default to false"
	[ "$ENABLE_AUTO_UPDATE" = "false" ] || fail "automatic update must default to false"
	[ -z "$TELEMETRY_ENDPOINT" ] || fail "telemetry endpoint must be empty"
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

	stats_body=$(awk '/^send_stats\(\) \{/{found=1} found{print} found && /^}/{exit}' "$script")
	printf '%s\n' "$stats_body" | grep -Fq 'return 0' || fail "send_stats is not a no-op: $script"
	if printf '%s\n' "$stats_body" | grep -Eq 'curl|wget|urllib|http'; then
		fail "send_stats contains a network operation: $script"
	fi

	update_body=$(awk '/^project_update\(\) \{/{found=1} found{print} found && /^}/{exit}' "$script")
	if printf '%s\n' "$update_body" | grep -Eq 'curl|wget|crontab|git (pull|fetch)'; then
		fail "project_update contains a remote or cron operation: $script"
	fi
done

if grep -R -E 'api\.kejilion\.pro|SH_Update_task|ENABLE_STATS="true"' "${implementations[@]}"; then
	fail "deprecated telemetry or updater code remains"
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

echo "PASS: project safety defaults"
