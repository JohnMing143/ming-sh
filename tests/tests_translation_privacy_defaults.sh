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

translation_scripts=(
	"$repo_root/translate.py"
	"$repo_root/en/to-en.py"
	"$repo_root/jp/to-jp.py"
	"$repo_root/kr/to-kr.py"
	"$repo_root/tw/to-tw.py"
)

for script in "${translation_scripts[@]}"; do
	set +e
	output=$(
		cd "$workdir"
		env -u ALLOW_REMOTE_TRANSLATION python3 "$script" 2>&1
	)
	status=$?
	set -e

	[ "$status" -eq 2 ] ||
		fail "translator did not stop with the privacy guard: $script (status $status)"
	printf '%s\n' "$output" | grep -Fq 'disabled by default' ||
		fail "translator did not explain the default denial: $script"
	printf '%s\n' "$output" | grep -Fq 'ALLOW_REMOTE_TRANSLATION=true' ||
		fail "translator did not document the explicit opt-in: $script"

	grep -Fq "REMOTE_TRANSLATION_ENV = 'ALLOW_REMOTE_TRANSLATION'" "$script" ||
		fail "translator is missing the shared opt-in name: $script"
	if grep -Eq '^from deep_translator import ' "$script"; then
		fail "translator imports its network client before opt-in: $script"
	fi
done

if find "$workdir" -mindepth 1 -print -quit | grep -q .; then
	fail "default-denied translators wrote files"
fi

echo "PASS: translation privacy defaults"
