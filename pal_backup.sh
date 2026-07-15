#!/usr/bin/env bash
set -euo pipefail

backup_root="${PALWORLD_BACKUP_DIR:-/home/game/palworld-backups}"
mkdir -p -- "$backup_root"
stage=$(mktemp -d "$backup_root/.stage.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
}
trap cleanup EXIT

docker cp steamcmd:/home/steam/Steam/steamapps/common/PalServer/Pal/Saved/. "$stage/Saved"
archive="$backup_root/palworld_$(date +"%Y%m%d%H%M%S").tar.gz"
tar -C "$stage" -czf "$archive" Saved
chmod 0600 "$archive"
printf '\033[0;32m游戏存档已导出至: %s\033[0m\n' "$archive"
