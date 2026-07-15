#!/usr/bin/env bash
set -euo pipefail

backup_root="${MC_BACKUP_DIR:-/home/game/mc-backups}"
mkdir -p -- "$backup_root"
stage=$(mktemp -d "$backup_root/.stage.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
}
trap cleanup EXIT

docker cp mcserver:/data/world/. "$stage/world"
archive="$backup_root/mcsave_$(date +"%Y%m%d%H%M%S").tar.gz"
tar -C "$stage" -czf "$archive" world
chmod 0600 "$archive"
printf '\033[0;32m游戏存档已导出至: %s\033[0m\n' "$archive"
