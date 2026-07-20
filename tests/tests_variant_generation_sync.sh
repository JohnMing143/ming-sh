#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required for variant generation checks"

# Roadmap Milestone 2: every localized entrypoint is generated from the root
# script — cn by marker substitution, en/jp/kr/tw by per-line catalog
# substitution. The committed variants must match regeneration exactly, so a
# hand edit to a generated file or a root change that skipped regeneration
# fails CI. This check is fully offline.
if ! env -u ALLOW_REMOTE_TRANSLATION python3 "$repo_root/translate.py" check --all; then
	fail "committed variants do not match regeneration; run: python3 translate.py generate --all"
fi

for lang in en jp kr tw; do
	[ -f "$repo_root/$lang/catalog.json" ] || fail "missing translation catalog: $lang/catalog.json"
	python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$repo_root/$lang/catalog.json" ||
		fail "translation catalog is not valid JSON: $lang/catalog.json"
done

echo "PASS: variant generation sync"
