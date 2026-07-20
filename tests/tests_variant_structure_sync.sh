#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# Roadmap Milestone 2: the translated implementations cannot be compared
# byte-for-byte, but after blanking string literals, comments, and heredoc
# bodies (where all translated text lives), every variant must reduce to
# exactly the root script's code skeleton. This is what makes a functional
# change that silently misses a localized copy fail CI.
normalizer="$repo_root/tests/normalize_shell_skeleton.py"
[ -f "$normalizer" ] || fail "missing skeleton normalizer: $normalizer"

command -v python3 >/dev/null 2>&1 || fail "python3 is required for skeleton comparison"

tmp_dir=$(mktemp -d "$repo_root/tests/.variant-structure-sync.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

python3 "$normalizer" "$repo_root/ming.sh" > "$tmp_dir/root.skel"
[ -s "$tmp_dir/root.skel" ] || fail "root skeleton is empty; the normalizer is broken"

for variant in cn en jp kr tw; do
	python3 "$normalizer" "$repo_root/$variant/ming.sh" > "$tmp_dir/$variant.skel"
	if ! diff -u "$tmp_dir/root.skel" "$tmp_dir/$variant.skel" > "$tmp_dir/$variant.diff"; then
		head -40 "$tmp_dir/$variant.diff" >&2
		fail "$variant/ming.sh code structure drifted from the root entrypoint; port the root change to this variant (translated strings may differ, code lines may not)"
	fi
done

echo "PASS: variant structure sync"
