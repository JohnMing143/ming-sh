#!/usr/bin/env bash
# shellcheck disable=SC2016
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

production_shell_files=()
while IFS= read -r shell_file; do
	production_shell_files+=("$shell_file")
done < <(find "$repo_root" -type f -name '*.sh' \
	-not -path "$repo_root/.git/*" \
	-not -path "$repo_root/tests/*" \
	-not -path "$repo_root/cn/tests/*" \
	-print)

for script in "${implementations[@]}"; do
	bash -n "$script"
	grep -Fq 'install_project_entrypoint()' "$script" || fail "explicit entrypoint installer is missing: $script"
	grep -Fq 'if [ -L "$PROJECT_INSTALL_PATH" ]; then' "$script" || fail "entrypoint symlink guard is missing: $script"
	grep -Fq 'PROJECT_LICENSE_ACCEPTED_FILE' "$script" || fail "license state marker is missing: $script"
	grep -Fq 'run_reviewed_remote_script()' "$script" || fail "remote script review gate is missing: $script"
	grep -Fq 'tmux new-session -d -s "$base_name-$tmuxd_ID" -- "${tmux_command[@]}"' "$script" || fail "tmux command is not executed as an array: $script"
	grep -Fq 'local DEVICE="/dev/$PARTITION"' "$script" || fail "format target is not constrained to /dev: $script"
	grep -Fq 'local confirmation_token="FORMAT $DEVICE"' "$script" || fail "destructive format confirmation is missing: $script"
	grep -Fq '\"password\": \"\"' "$script" || fail "cluster entries do not default to an empty password: $script"
	grep -Fq 'SSHPASS="$password" sshpass -e ssh' "$script" || fail "cluster password is exposed through argv: $script"
	if grep -Fq 'permission_granted=' "$script"; then
		fail "self-modifying license flag remains: $script"
	fi
	if grep -Fq 'for shell_rc in "$HOME/.bashrc"' "$script"; then
		fail "startup still edits shell profiles: $script"
	fi
	if grep -Eq 'read .*server_password|"password": "\$server_password"' "$script"; then
		fail "cluster passwords are still persisted: $script"
	fi
done

forbidden_pattern='--insecure|--no-check-certificate|StrictHostKeyChecking=no|UserKnownHostsFile=/dev/null|NOPASSWD:ALL|sshpass[[:space:]]+-p|chmod[[:space:]]+-R[[:space:]]+777'
if grep -En -- "$forbidden_pattern" "${production_shell_files[@]}"; then
	fail "an insecure transport, privilege, or permission default remains"
fi
if grep -En 'curl[[:space:]]+-[^[:space:]]*k' "${production_shell_files[@]}"; then
	fail "curl still disables TLS verification"
fi
if grep -En '^[[:space:]]*[^#]*(curl|wget)[^[:space:]]*[[:space:]].*http://' "${production_shell_files[@]}"; then
	fail "a production download still uses plaintext HTTP"
fi
if grep -En '^[[:space:]]*(iptables|ip6tables)[[:space:]]+(-F|-X)([[:space:]]|$)' "${production_shell_files[@]}"; then
	fail "a helper still flushes broad firewall state"
fi
if grep -En '^[[:space:]]*rm[[:space:]]+-rf[[:space:]]+(/home/docker|/home/web|/home/game|/var/log|/var/cache/apk|/etc/ssh)' "${production_shell_files[@]}"; then
	fail "an unguarded broad system-path deletion remains"
fi
if grep -En '^[[:space:]]*[^#]*(curl|wget)[^|]*\|[[:space:]]*(bash|sh)' "${production_shell_files[@]}"; then
	fail "a remote script pipeline remains"
fi
if grep -En 'bash[[:space:]]+<\(|bash[[:space:]]+-c[[:space:]]+"\$\((curl|wget)' "${production_shell_files[@]}"; then
	fail "a remote script process substitution remains"
fi
if grep -En '^[[:space:]]*[^#]*(curl|wget)[^[:space:]]*[[:space:]].*\.sh.*(&&|;).*(bash|sh|source|\./)' "${production_shell_files[@]}"; then
	fail "a download-and-execute command remains"
fi
grep -Fq '"bind": "127.0.0.1:8181"' "$repo_root/PandoraNext/config.json" || fail "PandoraNext is not bound to localhost"
grep -Fq '"disable_signup": true' "$repo_root/PandoraNext/config.json" || fail "PandoraNext signup is enabled by default"
[ "$(tr -d '[:space:]' < "$repo_root/PandoraNext/tokens.json")" = '{}' ] || fail "example tokens remain"

if grep -Eq '123456|0\.0\.0\.0|StrictHostKeyChecking=no|sshpass[[:space:]]+-p' "$repo_root/beifen.sh"; then
	fail "backup helper contains insecure connection defaults"
fi

echo "PASS: security hardening defaults"
