#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required for shared library checks"

# Roadmap Milestone 3: shared shell helpers have exactly one editable source
# under lib/; every shipped copy is inlined between generation markers and
# must stay byte-identical to it. Shipped files remain self-contained and
# never source library code at runtime.
[ -f "$repo_root/lib/remote_script.sh" ] || fail "missing canonical library: lib/remote_script.sh"
bash -n "$repo_root/lib/remote_script.sh" || fail "canonical library fails bash syntax check"

python3 "$repo_root/lib/inline.py" --check ||
	fail "an inlined shared-library copy drifted; edit lib/ and run: python3 lib/inline.py"

# No consumer may source the library at runtime.
if grep -Rn --include='*.sh' -E '(^|[^#])\b(source|\.)[[:space:]]+.*lib/remote_script\.sh' \
	"$repo_root/ming.sh" "$repo_root/mc.sh" "$repo_root/palworld.sh" "$repo_root/hermes_manager.sh"; then
	fail "a shipped script sources the library at runtime instead of inlining it"
fi

echo "PASS: shared lib sync"
