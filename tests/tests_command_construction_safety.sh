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
	grep -Fq "case \"\$rx_threshold_gb\" in ''|*[!0-9]*) rx_threshold_gb=100 ;; esac" "$script" ||
		fail "traffic-limit threshold input is not normalized to numeric: $script"
	grep -Fq 'sed -i "s/^rx_threshold_gb=110$/rx_threshold_gb=$rx_threshold_gb/"' "$script" ||
		fail "traffic-limit rx substitution is not anchored to its assignment: $script"
	grep -Fq 'sed -i "s/^tx_threshold_gb=120$/tx_threshold_gb=$tx_threshold_gb/"' "$script" ||
		fail "traffic-limit tx substitution is not anchored to its assignment: $script"

	# Project-owned scripts that are installed for cron/tmux/profile use must
	# be fetched through the reviewed downloader (HTTPS + bash -n + digest),
	# not raw curl/wget.
	grep -Fq 'download_reviewed_remote_script --install "${PROJECT_DOWNLOAD_BASE}/auto_cert_renewal.sh" ~/auto_cert_renewal.sh' "$script" ||
		fail "auto_cert_renewal.sh is not installed through the reviewed downloader: $script"
	grep -Fq 'download_reviewed_remote_script --install "${PROJECT_DOWNLOAD_BASE}/CF-Under-Attack.sh" ~/CF-Under-Attack.sh' "$script" ||
		fail "CF-Under-Attack.sh is not installed through the reviewed downloader: $script"
	grep -Fq 'download_reviewed_remote_script --install "${PROJECT_DOWNLOAD_BASE}/Limiting_Shut_down1.sh" ~/Limiting_Shut_down.sh' "$script" ||
		fail "Limiting_Shut_down1.sh is not installed through the reviewed downloader: $script"
	grep -Fq 'download_reviewed_remote_script --install "${PROJECT_DOWNLOAD_BASE}/TG-check-notify.sh" ~/TG-check-notify.sh' "$script" ||
		fail "TG-check-notify.sh is not installed through the reviewed downloader: $script"
	grep -Fq 'download_reviewed_remote_script --install "${PROJECT_DOWNLOAD_BASE}/TG-SSH-check-notify.sh" ~/TG-SSH-check-notify.sh' "$script" ||
		fail "TG-SSH-check-notify.sh is not installed through the reviewed downloader: $script"

	# The Composer installer must be verified against the published
	# installer.sig digest, not fetched blindly via php copy().
	grep -Fq 'https://composer.github.io/installer.sig' "$script" ||
		fail "Composer install does not verify the installer digest: $script"
	if grep -Fq "php -r \"copy('https://getcomposer.org/installer'" "$script"; then
		fail "Composer installer is still fetched via unverified php copy(): $script"
	fi

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
	if grep -Fq "grep -v 'reboot'" "$script"; then
		fail "a broad crontab reboot filter that can delete unrelated jobs remains: $script"
	fi
done

# palworld.sh interactive values must not reach a sed replacement unescaped
# (a literal delimiter or GNU sed `e` flag would turn them into commands).
palworld="$repo_root/palworld.sh"
bash -n "$palworld"
grep -Fq 'sed_escape_replacement "$server_password"' "$palworld" ||
	fail "PalWorld server password is not escaped for the sed replacement"
grep -Fq 'ServerPassword=\"$server_password_escaped\"' "$palworld" ||
	fail "PalWorld password substitution does not use the escaped value"
if grep -Fq 'sed -i "s/ServerPassword=' "$palworld"; then
	fail "PalWorld password still uses a /-delimited sed replacement"
fi
grep -Fq "case \$exp_rate in" "$palworld" ||
	fail "PalWorld exp-rate input is not case-normalized"
if grep -Fq 'sed -i "s/ExpRate=1.000000/ExpRate=$ExpRate/"' "$palworld"; then
	fail "PalWorld exp-rate still reaches an unescaped /-delimited sed replacement"
fi

echo "PASS: command construction safety"
