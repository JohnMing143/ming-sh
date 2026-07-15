#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_HOST:?Set BACKUP_HOST to the destination host}"

BACKUP_USER="${BACKUP_USER:-root}"
BACKUP_PORT="${BACKUP_PORT:-22}"
BACKUP_SOURCE_DIR="${BACKUP_SOURCE_DIR:-/home/web}"
BACKUP_OUTPUT_DIR="${BACKUP_OUTPUT_DIR:-/home}"
BACKUP_REMOTE_DIR="${BACKUP_REMOTE_DIR:-/home}"
BACKUP_KEEP_COUNT="${BACKUP_KEEP_COUNT:-5}"
BACKUP_STRICT_HOST_KEY_CHECKING="${BACKUP_STRICT_HOST_KEY_CHECKING:-accept-new}"

case "$BACKUP_PORT" in
	''|*[!0-9]*) echo "BACKUP_PORT must be numeric" >&2; exit 2 ;;
esac
[ "$BACKUP_PORT" -ge 1 ] && [ "$BACKUP_PORT" -le 65535 ] || {
	echo "BACKUP_PORT must be between 1 and 65535" >&2
	exit 2
}
case "$BACKUP_KEEP_COUNT" in
	''|*[!0-9]*) echo "BACKUP_KEEP_COUNT must be numeric" >&2; exit 2 ;;
esac
case "$BACKUP_STRICT_HOST_KEY_CHECKING" in
	yes|accept-new) ;;
	*) echo "BACKUP_STRICT_HOST_KEY_CHECKING must be yes or accept-new" >&2; exit 2 ;;
esac
[ -d "$BACKUP_SOURCE_DIR" ] || {
	echo "Backup source does not exist: $BACKUP_SOURCE_DIR" >&2
	exit 1
}
[ "$BACKUP_SOURCE_DIR" != "/" ] || {
	echo "Refusing to archive the filesystem root" >&2
	exit 2
}

mkdir -p -- "$BACKUP_OUTPUT_DIR"
archive="$BACKUP_OUTPUT_DIR/web_$(date +"%Y%m%d%H%M%S").tar.gz"
tar -C "$(dirname -- "$BACKUP_SOURCE_DIR")" -czf "$archive" "$(basename -- "$BACKUP_SOURCE_DIR")"

scp_args=(-P "$BACKUP_PORT" -o StrictHostKeyChecking="$BACKUP_STRICT_HOST_KEY_CHECKING")
if [ -n "${BACKUP_IDENTITY_FILE:-}" ]; then
	[ -f "$BACKUP_IDENTITY_FILE" ] || {
		echo "Identity file does not exist: $BACKUP_IDENTITY_FILE" >&2
		exit 1
	}
	scp_args+=(-i "$BACKUP_IDENTITY_FILE")
fi

if [ -n "${BACKUP_PASSWORD:-}" ]; then
	command -v sshpass >/dev/null 2>&1 || {
		echo "sshpass is required when BACKUP_PASSWORD is used" >&2
		exit 1
	}
	SSHPASS="$BACKUP_PASSWORD" sshpass -e scp "${scp_args[@]}" -- "$archive" "$BACKUP_USER@$BACKUP_HOST:$BACKUP_REMOTE_DIR/"
else
	scp "${scp_args[@]}" -- "$archive" "$BACKUP_USER@$BACKUP_HOST:$BACKUP_REMOTE_DIR/"
fi

mapfile -t archives < <(find "$BACKUP_OUTPUT_DIR" -maxdepth 1 -type f -name 'web_*.tar.gz' -printf '%T@ %p\n' | sort -nr | cut -d' ' -f2-)
if [ "${#archives[@]}" -gt "$BACKUP_KEEP_COUNT" ]; then
	for old_archive in "${archives[@]:$BACKUP_KEEP_COUNT}"; do
		rm -f -- "$old_archive"
	done
fi
