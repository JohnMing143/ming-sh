#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d "$repo_root/.translation-privacy-test.XXXXXX")

cleanup() {
	[ "${BASH_SUBSHELL:-0}" -eq 0 ] || return 0
	rm -rf -- "$workdir"
}
trap cleanup EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

tool="$repo_root/translate.py"

# The remote-translation subcommand must refuse to run without the explicit
# opt-in, before importing its network client or writing anything.
set +e
output=$(
	cd "$workdir"
	env -u ALLOW_REMOTE_TRANSLATION python3 "$tool" translate-missing --lang en 2>&1
)
status=$?
set -e

[ "$status" -eq 2 ] ||
	fail "remote translation did not stop with the privacy guard (status $status)"
printf '%s\n' "$output" | grep -Fq 'disabled by default' ||
	fail "remote translation did not explain the default denial"
printf '%s\n' "$output" | grep -Fq 'ALLOW_REMOTE_TRANSLATION=true' ||
	fail "remote translation did not document the explicit opt-in"

grep -Fq "REMOTE_TRANSLATION_ENV = 'ALLOW_REMOTE_TRANSLATION'" "$tool" ||
	fail "the shared opt-in name is missing"
if grep -Eq '^from deep_translator import |^import deep_translator' "$tool"; then
	fail "the network client is imported before opt-in"
fi

# Offline subcommands must work without the opt-in and without the network:
# check verifies every committed variant against regeneration.
env -u ALLOW_REMOTE_TRANSLATION python3 "$tool" check --all >/dev/null ||
	fail "offline variant check requires the remote opt-in or fails"
env -u ALLOW_REMOTE_TRANSLATION python3 "$tool" status --all >/dev/null ||
	fail "offline status report requires the remote opt-in or fails"

if find "$workdir" -mindepth 1 -print -quit | grep -q .; then
	fail "default-denied translation wrote files"
fi

echo "PASS: translation privacy defaults"
