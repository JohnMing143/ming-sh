#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "请使用 root 运行此升级工具。" >&2
	exit 1
fi

if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
else
	echo "无法检测操作系统类型。" >&2
	exit 1
fi

current_version=$(ssh -V 2>&1 | head -n 1)
printf '当前 OpenSSH: %s\n' "$current_version"
echo "此工具只使用发行版签名的软件仓库升级 OpenSSH，不再下载和编译未校验的源码包。"
read -r -p "继续升级 OpenSSH 软件包吗？(y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消。"; exit 0; }

case "${ID:-}" in
	ubuntu|debian)
		export DEBIAN_FRONTEND=noninteractive
		apt-get update
		apt-get install --only-upgrade -y openssh-client openssh-server
		;;
	centos|rhel|almalinux|rocky|fedora)
		if command -v dnf >/dev/null 2>&1; then
			dnf upgrade -y openssh openssh-clients openssh-server
		else
			yum update -y openssh openssh-clients openssh-server
		fi
		;;
	alpine)
		apk update
		apk upgrade openssh openssh-client openssh-server
		;;
	arch)
		pacman -Syu --noconfirm openssh
		;;
	opensuse*|sles)
		zypper --non-interactive update openssh
		;;
	*)
		echo "暂不支持该发行版: ${ID:-unknown}" >&2
		exit 1
		;;
esac

if command -v sshd >/dev/null 2>&1; then
	sshd -t
fi

if command -v systemctl >/dev/null 2>&1; then
	systemctl restart ssh 2>/dev/null || systemctl restart sshd
elif command -v rc-service >/dev/null 2>&1; then
	rc-service sshd restart
elif command -v service >/dev/null 2>&1; then
	service ssh restart 2>/dev/null || service sshd restart
else
	echo "OpenSSH 已升级，但未检测到受支持的服务管理器；请手动重启 SSH 服务。"
fi

printf '升级后 OpenSSH: '
ssh -V
