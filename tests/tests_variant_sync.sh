#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# The root entrypoint is the canonical Simplified Chinese implementation.
# cn/ming.sh must stay byte-identical to it except for the single variant
# marker line, so fixes applied to the root can never silently miss the
# localized copy again.
expected_marker='canshu="CN"'
root_marker='canshu="default"'

grep -Fxq "$root_marker" "$repo_root/ming.sh" ||
	fail "root entrypoint no longer carries the expected variant marker: $root_marker"
grep -Fxq "$expected_marker" "$repo_root/cn/ming.sh" ||
	fail "cn entrypoint no longer carries the expected variant marker: $expected_marker"

if ! diff -u \
	<(sed "s/^${root_marker}\$/${expected_marker}/" "$repo_root/ming.sh") \
	"$repo_root/cn/ming.sh" >&2; then
	fail "cn/ming.sh drifted from the root entrypoint; regenerate it from ming.sh with only the canshu marker changed"
fi

# The translated variants cannot be compared byte-for-byte, but hardening
# and compatibility guards must exist in every implementation.
implementations=(
	"$repo_root/ming.sh"
	"$repo_root/cn/ming.sh"
	"$repo_root/en/ming.sh"
	"$repo_root/jp/ming.sh"
	"$repo_root/kr/ming.sh"
	"$repo_root/tw/ming.sh"
)

for script in "${implementations[@]}"; do
	grep -Fq 'jammy focal bullseye buster' "$script" ||
		fail "XanMod end-of-support codename guard is missing: $script"
done

echo "PASS: variant sync"
