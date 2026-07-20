#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/network-optimize.sh"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

bash -n "$script" || fail "network-optimize.sh fails bash syntax check"

# Roadmap Milestone 3, item 5: the auto-tune writer uses a project-tagged
# sysctl path and carries a project marker, with migration from the old name.
grep -Fq 'CONF="/etc/sysctl.d/99-ming-sh-network.conf"' "$script" ||
	fail "auto-tune config is not on the project-tagged path"
grep -Fq 'OLD_CONF="/etc/sysctl.d/99-network-optimize.conf"' "$script" ||
	fail "auto-tune config does not migrate the legacy path"
grep -Fq '# ming-sh-network-optimize' "$script" ||
	fail "generated config is missing the project marker comment"

# Restore must return to system defaults, never re-apply a prior optimization.
if grep -Eq 'cp "\$latest_bak" "\$CONF"|latest_bak=' "$script"; then
	fail "restore still re-applies a previous optimization backup instead of returning to defaults"
fi
grep -Fq 'sysctl --system' "$script" ||
	fail "restore does not reload system defaults"

# The entrypoints must detect and clean both the new and legacy paths.
for entry in "$repo_root/ming.sh" "$repo_root/cn/ming.sh" "$repo_root/en/ming.sh" \
	"$repo_root/jp/ming.sh" "$repo_root/kr/ming.sh" "$repo_root/tw/ming.sh"; do
	grep -Fq 'rm -f /etc/sysctl.d/99-ming-sh-network.conf' "$entry" ||
		fail "entrypoint does not clean the project-tagged auto-tune path: $entry"
	grep -Fq '[ -f /etc/sysctl.d/99-ming-sh-network.conf ] || [ -f /etc/sysctl.d/99-network-optimize.conf ]' "$entry" ||
		fail "entrypoint does not detect both auto-tune paths: $entry"
done

echo "PASS: network optimize paths"
