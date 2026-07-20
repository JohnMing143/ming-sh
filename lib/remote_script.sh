# shellcheck shell=bash
# Canonical remote-script validator shared by the main entrypoint and the
# standalone helpers. Edit this file only, then run: python3 lib/inline.py
# The inlined copies carry generation markers and must stay byte-identical
# (tests/tests_shared_lib_sync.sh enforces this). Shipped files stay
# self-contained; nothing sources this file at runtime.

remote_script_sha256() {
	local script_path="$1"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$script_path" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$script_path" | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$script_path" | awk '{print $NF}'
	else
		return 1
	fi
}

run_reviewed_remote_script() {
	local script_url="$1"
	shift
	local cache_dir script_path digest exit_status
	case "$script_url" in
		https://*) ;;
		*) echo "拒绝下载非 HTTPS 脚本: $script_url"; return 1 ;;
	esac
	cache_dir="${PROJECT_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/${PROJECT_ID:-ming-sh}}/remote-scripts"
	[ ! -L "$cache_dir" ] || { echo "拒绝使用符号链接缓存目录: $cache_dir"; return 1; }
	mkdir -p -- "$cache_dir" || return 1
	[ -O "$cache_dir" ] || { echo "远程脚本缓存目录不属于当前用户: $cache_dir"; return 1; }
	chmod 0700 "$cache_dir" || return 1
	script_path=$(mktemp "$cache_dir/review.XXXXXX.sh") || return 1
	chmod 0600 "$script_path"

	if command -v curl >/dev/null 2>&1; then
		curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 --output "$script_path" "$script_url" || {
			rm -f -- "$script_path"
			return 1
		}
	elif command -v wget >/dev/null 2>&1; then
		wget --https-only --secure-protocol=TLSv1_2 -qO "$script_path" "$script_url" || {
			rm -f -- "$script_path"
			return 1
		}
	else
		echo "需要 curl 或 wget 才能下载脚本。"
		rm -f -- "$script_path"
		return 1
	fi
	[ -s "$script_path" ] || { echo "下载结果为空。"; rm -f -- "$script_path"; return 1; }
	bash -n "$script_path" || { echo "远程脚本未通过 Bash 语法检查: $script_path"; rm -f -- "$script_path"; return 1; }
	digest=$(remote_script_sha256 "$script_path" 2>/dev/null) || digest="unavailable"

	printf '远程脚本已通过 HTTPS 下载和 Bash 语法检查，正在自动执行。\n来源: %s\nSHA-256: %s\n' "$script_url" "$digest"
	bash "$script_path" "$@"
	exit_status=$?
	rm -f -- "$script_path"
	return "$exit_status"
}
