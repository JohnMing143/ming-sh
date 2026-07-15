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
	grep -Fq 'project_entrypoint_is_managed_file()' "$script" || fail "entrypoint ownership marker check is missing: $script"
	grep -Fq 'install_project_entrypoint()' "$script" || fail "guarded entrypoint installer is missing: $script"
	grep -Fq 'if [ -L "$PROJECT_INSTALL_PATH" ]; then' "$script" || fail "entrypoint symlink guard is missing: $script"
	grep -Fq '拒绝覆盖现有非本项目命令' "$script" || fail "regular command conflict guard is missing: $script"
	grep -Fq 'install_project_entrypoint >/dev/null 2>&1 || true' "$script" || fail "automatic entrypoint installation is missing: $script"
	grep -Fq 'PROJECT_LICENSE_ACCEPTED_FILE' "$script" || fail "license state marker is missing: $script"
	grep -Fq 'migrate_legacy_license_acceptance || true' "$script" || fail "legacy license acceptance migration is missing: $script"
	grep -Fq 'run_reviewed_remote_script()' "$script" || fail "remote script validator is missing: $script"
	grep -Fq "curl --fail --show-error --silent --location --proto '=https' --tlsv1.2" "$script" || fail "verified HTTPS remote download is missing: $script"
	grep -Fq 'bash -n "$script_path"' "$script" || fail "remote Bash syntax validation is missing: $script"
	grep -Fq 'bash "$script_path" "$@"' "$script" || fail "validated remote scripts are not executed automatically: $script"
	grep -Fq 'tmux new-session -d -s "$base_name-$tmuxd_ID" -- "${tmux_command[@]}"' "$script" || fail "tmux command is not executed as an array: $script"
	grep -Fq 'local DEVICE="/dev/$PARTITION"' "$script" || fail "format target is not constrained to /dev: $script"
	grep -Fq "lsblk -dnro TYPE \"\$DEVICE\"" "$script" || fail "format target type validation is missing: $script"
	grep -Fq 'findmnt -rn -S "$DEVICE"' "$script" || fail "mounted-device format guard is missing: $script"
	grep -Fq '[[ ! "$CONFIRM" =~ ^[Yy]$ ]]' "$script" || fail "single-step format confirmation is missing: $script"
	grep -Fq 'safe_remove_path()' "$script" || fail "canonical deletion guard is missing: $script"
	grep -Fq "''|/|//*)" "$script" || fail "root and ambiguous deletion targets are not rejected before rm: $script"
	grep -Fq 'read -e -s -p' "$script" || fail "hidden cluster password capture is missing: $script"
	grep -Fq 'server_password_encoded=' "$script" || fail "cluster password storage encoding is missing: $script"
	grep -Fq '\"password\": \"base64:$server_password_encoded\"' "$script" || fail "cluster password is not persisted for automation: $script"
	grep -Fq 'SSHPASS="$password" sshpass -e ssh' "$script" || fail "cluster password is exposed through argv: $script"
	grep -Fq 'backup_iptables_rules()' "$script" || fail "firewall backup helper is missing: $script"
	grep -Fq 'iptables_close_all()' "$script" || fail "close-all firewall feature is missing: $script"
	grep -Fq 'ALL=(ALL) NOPASSWD:ALL' "$script" || fail "explicit passwordless administrator feature is unavailable: $script"
	if grep -Eq '^[[:space:]]*permission_granted=|sed[[:space:]]+-i.*permission_granted' "$script"; then
		fail "self-modifying license state remains: $script"
	fi
	if grep -Fq 'for shell_rc in "$HOME/.bashrc"' "$script"; then
		fail "startup still edits shell profiles: $script"
	fi
	if grep -Eq '输入 VIEW|Type VIEW|RUN \$digest|非交互环境拒绝执行未固定摘要' "$script"; then
		fail "remote execution still adds a manual review step: $script"
	fi
done

forbidden_pattern='--insecure|--no-check-certificate|StrictHostKeyChecking=no|UserKnownHostsFile=/dev/null|sshpass[[:space:]]+-p|chmod[[:space:]]+-R[[:space:]]+777'
if grep -En -- "$forbidden_pattern" "${production_shell_files[@]}"; then
	fail "an insecure transport, privilege, or permission default remains"
fi
if grep -En 'curl[[:space:]]+-[^[:space:]]*k' "${production_shell_files[@]}"; then
	fail "curl still disables TLS verification"
fi
if grep -En '^[[:space:]]*[^#]*(curl|wget)[^[:space:]]*[[:space:]].*http://' "${production_shell_files[@]}"; then
	fail "a production download still uses plaintext HTTP"
fi
for firewall_helper in "$repo_root/ldnmp.sh" "$repo_root/auto_cert_renewal-1.sh"; do
	if grep -En '^[[:space:]]*(iptables|ip6tables)[[:space:]]+(-F|-X)([[:space:]]|$)' "$firewall_helper"; then
		fail "an unrelated helper still flushes broad firewall state: $firewall_helper"
	fi
done
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
grep -Fq '"bind": "0.0.0.0:8181"' "$repo_root/PandoraNext/config.json" || fail "PandoraNext network access default is unavailable"
grep -Fq '"server_tokens": true' "$repo_root/PandoraNext/config.json" || fail "PandoraNext server tokens are disabled"
grep -Fq '"disable_signup": false' "$repo_root/PandoraNext/config.json" || fail "PandoraNext signup is disabled"
grep -Fq '"test-1"' "$repo_root/PandoraNext/tokens.json" || fail "PandoraNext token examples are missing"

if grep -Eq '123456|0\.0\.0\.0|StrictHostKeyChecking=no|sshpass[[:space:]]+-p' "$repo_root/beifen.sh"; then
	fail "backup helper contains insecure connection defaults"
fi

echo "PASS: security hardening defaults"
