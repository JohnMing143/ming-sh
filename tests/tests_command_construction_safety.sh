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

for script in "${implementations[@]}"; do
	bash -n "$script"

	grep -Fq 'read -r -a docker_command <<< "$dockername"' "$script" ||
		fail "Docker create input is not parsed into an argument array: $script"
	grep -Fq '"${docker_command[@]}"' "$script" ||
		fail "Docker create arguments are not executed as an array: $script"
	grep -Fq 'printf '\''%q '\'' "${docker_run_args[@]}" >> "$RESTORE_SCRIPT"' "$script" ||
		fail "generated Docker restore command is not shell-quoted: $script"
	grep -Fq '"${docker_run_args[@]}"' "$script" ||
		fail "Docker restore arguments are not executed as an array: $script"
	grep -Fq 'local -a cmd=(openclaw agents set-identity --agent "$agent_id")' "$script" ||
		fail "OpenClaw identity command is not an array: $script"
	grep -Fq '"${cmd[@]}"' "$script" ||
		fail "OpenClaw identity arguments are not preserved: $script"
	grep -Fq '[[ ! "$kuaijiejian" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]' "$script" ||
		fail "shortcut name allowlist is missing: $script"
	grep -Fq 'shortcut_conflict="false"' "$script" ||
		fail "shortcut conflict protection is missing: $script"

	if grep -Eq '^[[:space:]]*\$dockername[[:space:]]*$' "$script"; then
		fail "interactive input is still executed as a command: $script"
	fi
	if grep -Fq 'eval "docker run -d --name' "$script"; then
		fail "Docker restore still uses eval: $script"
	fi
	if grep -Fq 'eval "$cmd"' "$script"; then
		fail "OpenClaw identity command still uses eval: $script"
	fi
	if grep -Fq 'echo "docker run -d --name $c $PORT_ARGS' "$script"; then
		fail "generated Docker restore script still concatenates arguments: $script"
	fi
	if grep -Eq 'read .*get\.docker\.com.*\|.*sh' "$script"; then
		fail "interactive help still recommends piping a remote installer to a shell: $script"
	fi
done

echo "PASS: command construction safety"
