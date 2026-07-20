#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

implementations=(
	"$repo_root/ming.sh"
	"$repo_root/cn/ming.sh"
	"$repo_root/en/ming.sh"
	"$repo_root/jp/ming.sh"
	"$repo_root/kr/ming.sh"
	"$repo_root/tw/ming.sh"
)

# Roadmap Milestone 3, item 4: project-managed cron jobs go through shared
# tag helpers so removal is exact and can never delete unrelated entries.
for script in "${implementations[@]}"; do
	bash -n "$script"

	grep -Fq 'cron_install_tagged() {' "$script" ||
		fail "shared tagged cron install helper is missing: $script"
	grep -Fq 'cron_remove_tagged() {' "$script" ||
		fail "shared tagged cron remove helper is missing: $script"
	grep -Fq 'local tag="# ${PROJECT_CRON_TAG}:$1"' "$script" ||
		fail "cron helpers do not tag entries with the project cron tag: $script"

	# The migrated project-managed writers must use the helpers.
	grep -Fq 'cron_install_tagged logrotate ' "$script" ||
		fail "logrotate cron writer was not migrated to the tagged helper: $script"
	grep -Fq 'cron_install_tagged cert-renew ' "$script" ||
		fail "certificate renewal cron writer was not migrated: $script"
	grep -Fq 'cron_install_tagged tg-monitor ' "$script" ||
		fail "TG monitor cron writer was not migrated: $script"

	# The broad-word filters these replaced must not come back.
	if grep -Fq "grep -v 'logrotate'" "$script"; then
		fail "a broad 'logrotate' crontab filter that can delete unrelated jobs returned: $script"
	fi
	if grep -Fq "grep -v '~/TG-check-notify.sh'" "$script"; then
		fail "the untagged TG monitor crontab filter returned: $script"
	fi
done

echo "PASS: cron tagging"
