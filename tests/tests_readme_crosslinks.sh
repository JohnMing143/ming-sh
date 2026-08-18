#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# AGENTS.md documentation language policy: one user-facing README per shipped
# locale, and each one's language-selector line must cross-link every sibling.
readmes=(README.md README.en.md README.tw.md README.ja.md README.kr.md)

for readme in "${readmes[@]}"; do
	[ -f "$repo_root/$readme" ] || fail "missing user-facing README: $readme"
	for sibling in "${readmes[@]}"; do
		[ "$readme" = "$sibling" ] && continue
		grep -Fq "($sibling)" "$repo_root/$readme" ||
			fail "$readme does not cross-link $sibling"
	done
done

echo "PASS: README language cross-links"
