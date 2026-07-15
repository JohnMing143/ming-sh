#!/bin/bash
project_script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
if [ -r "$project_script_dir/config/project.conf" ]; then
	# shellcheck disable=SC1091
	. "$project_script_dir/config/project.conf"
fi
unset project_script_dir
PROJECT_COMMAND="${PROJECT_COMMAND:-m}"
PROJECT_REPO="${PROJECT_REPO:-JohnMing143/ming-sh}"
PROJECT_BRANCH="${PROJECT_BRANCH:-main}"
PROJECT_REPO_URL="${PROJECT_REPO_URL:-https://github.com/${PROJECT_REPO}}"
PROJECT_RAW_BASE="${PROJECT_RAW_BASE:-https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}}"
GITHUB_PROXY_BASE="${GITHUB_PROXY_BASE:-}"
if [ -n "$GITHUB_PROXY_BASE" ]; then
	PROJECT_DOWNLOAD_BASE="${PROJECT_DOWNLOAD_BASE:-${GITHUB_PROXY_BASE%/}/${PROJECT_RAW_BASE#https://}}"
else
	PROJECT_DOWNLOAD_BASE="${PROJECT_DOWNLOAD_BASE:-$PROJECT_RAW_BASE}"
fi
UPSTREAM_PALWORLD_SETTINGS_URL="${UPSTREAM_PALWORLD_SETTINGS_URL:-https://kejilion.pro/PalWorldSettings.ini}"
ENABLE_SELF_UPDATE="${ENABLE_SELF_UPDATE:-false}"

run_reviewed_remote_script() {
    local script_url="$1"
    local cache_dir script_path digest confirmation
    case "$script_url" in https://*) ;; *) echo "拒绝非 HTTPS 脚本: $script_url"; return 1 ;; esac
    cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/ming-sh/remote-scripts"
    [ ! -L "$cache_dir" ] || { echo "拒绝符号链接缓存目录。"; return 1; }
    mkdir -p -- "$cache_dir" && chmod 0700 "$cache_dir" || return 1
    [ -O "$cache_dir" ] || { echo "缓存目录不属于当前用户。"; return 1; }
    script_path=$(mktemp "$cache_dir/review.XXXXXX.sh") || return 1
    chmod 0600 "$script_path"
    curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 --output "$script_path" "$script_url" || return 1
    bash -n "$script_path" || { echo "远程脚本语法检查失败: $script_path"; return 1; }
    digest=$(sha256sum "$script_path" | awk '{print $1}') || return 1
    printf '脚本尚未执行。\n来源: %s\n文件: %s\nSHA-256: %s\n' "$script_url" "$script_path" "$digest"
    [ -t 0 ] || { echo "非交互环境拒绝执行未固定摘要的脚本。"; return 1; }
    read -r -p "输入 RUN $digest 执行: " confirmation
    [ "$confirmation" = "RUN $digest" ] || { echo "脚本未执行。"; return 1; }
    bash "$script_path"
}

ln -sf ~/palworld.sh /usr/local/bin/p

ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
}


install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            if command -v apt &>/dev/null; then
                apt update -y && apt install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update && yum -y install "$package"
            elif command -v apk &>/dev/null; then
                apk update && apk add "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        fi
    done

    return 0
}


remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        elif command -v apk &>/dev/null; then
            apk del "$package"
        else
            echo "未知的包管理器!"
            return 1
        fi
    done

    return 0
}


break_end() {
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
}

palworld() {
            p
            exit
}


install_add_docker() {
    if [ -f "/etc/alpine-release" ]; then
        apk update
        apk add docker docker-compose
        rc-update add docker default
        service docker start
    else
        run_reviewed_remote_script https://get.docker.com && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin
        systemctl start docker
        systemctl enable docker
    fi
}

install_docker() {
    if ! command -v docker &>/dev/null; then
        install_add_docker
    else
        echo "Docker 已经安装"
    fi
}

pal_start() {
    ip_address
    tmux new -d -s my1 "docker exec -it steamcmd bash -c '/home/steam/Steam/steamapps/common/PalServer/PalServer.sh'"
    echo -e "\033[0;32m幻兽帕鲁服务启动啦！\033[0m"
    echo -e "\033[0;32m游戏下载地址: https://store.steampowered.com/app/1623730\033[0m"
    echo -e "\033[0;32m进入游戏连接:\033[93m $ipv4_address:8255 \033[0;32m开始冒险吧！\033[0m"

}

pal_backup() {
  local target="$HOME/pal_backup.sh"
  {
    printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
    declare -f pal_export_world
    printf '\npal_export_world\n'
  } > "$target" || return 1
  chmod 0700 "$target"
}

pal_set_backup_cron() {
  local schedule="$1"
  local cron_tag="# ming-sh:palworld-backup"
  local cron_job="$schedule $HOME/pal_backup.sh $cron_tag"
  (crontab -l 2>/dev/null || true) | grep -vF "$cron_tag" | { cat; printf '%s\n' "$cron_job"; } | crontab -
}

pal_archive_is_safe() {
    local archive="$1"
    local listing
    listing=$(tar -tzf "$archive") || return 1
    printf '%s\n' "$listing" | awk '
        /^\// { bad=1 }
        /(^|\/)\.\.($|\/)/ { bad=1 }
        END { exit bad }
    '
}

pal_export_world() {
    local backup_root="/home/game/palworld-backups"
    local stage archive
    mkdir -p -- "$backup_root"
    stage=$(mktemp -d "$backup_root/.stage.XXXXXX") || return 1
    if ! docker cp steamcmd:/home/steam/Steam/steamapps/common/PalServer/Pal/Saved/. "$stage/Saved"; then
        rm -rf -- "$stage"
        return 1
    fi
    archive="$backup_root/palworld_$(date +"%Y%m%d%H%M%S").tar.gz"
    if tar -C "$stage" -czf "$archive" Saved; then
        chmod 0600 "$archive"
        rm -rf -- "$stage"
        printf '\033[0;32m游戏存档已导出至: %s\033[0m\n' "$archive"
    else
        rm -rf -- "$stage" "$archive"
        return 1
    fi
}

pal_restore_world() {
    local backup_root="/home/game/palworld-backups"
    local latest_archive stage previous_saved failed_saved saved_path
    latest_archive=$(find "$backup_root" -maxdepth 1 -type f -name 'palworld_*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
    [ -n "$latest_archive" ] || { echo "未找到 Palworld 备份。"; return 1; }
    pal_archive_is_safe "$latest_archive" || { echo "备份包含不安全路径，拒绝恢复。"; return 1; }
    stage=$(mktemp -d "$backup_root/.restore.XXXXXX") || return 1
    tar -C "$stage" -xzf "$latest_archive" || { rm -rf -- "$stage"; return 1; }
    [ -d "$stage/Saved" ] || { echo "备份缺少 Saved 目录。"; rm -rf -- "$stage"; return 1; }

    saved_path="/home/steam/Steam/steamapps/common/PalServer/Pal/Saved"
    previous_saved="${saved_path}.ming-backup-$(date +"%Y%m%d%H%M%S")"
    failed_saved="${saved_path}.failed-$(date +"%Y%m%d%H%M%S")"
    tmux kill-session -t my1 >/dev/null 2>&1 || true
    docker stop steamcmd >/dev/null 2>&1 || { rm -rf -- "$stage"; return 1; }
    docker exec steamcmd sh -c 'set -eu; mv -- "$1" "$2"; mkdir -p -- "$1"' sh "$saved_path" "$previous_saved" || { rm -rf -- "$stage"; return 1; }
    if docker cp "$stage/Saved/." "steamcmd:$saved_path/"; then
        docker exec -u root steamcmd sh -c 'chown -R steam:steam "$1" && chmod -R u+rwX,g+rwX,o-rwx "$1"' sh "$saved_path"
        echo "恢复完成；旧存档保留在容器内: $previous_saved"
    else
        docker exec steamcmd sh -c 'set -eu; mv -- "$1" "$3"; mv -- "$2" "$1"' sh "$saved_path" "$previous_saved" "$failed_saved"
        rm -rf -- "$stage"
        return 1
    fi
    rm -rf -- "$stage"
    docker restart steamcmd >/dev/null 2>&1
    pal_start
}

pal_install_status() {
  CONTAINER_NAME="steamcmd"

  # 检查容器是否已安装
  if [ "$(docker ps -a -q -f name=$CONTAINER_NAME 2>/dev/null)" ]; then
      container_status="\e[32m幻兽帕鲁服务已安装\e[0m"  # 绿色
  else
      container_status="\e[90m幻兽帕鲁服务未安装\e[0m"  # 灰色
  fi

  SESSION_NAME="my1"

  ip_address
  # 检查 tmux 中是否存在指定的工作区
  if tmux has-session -t $SESSION_NAME 2>/dev/null; then
      tmux_status="\e[32m已开服:\033[93m $ipv4_address:8255\e[0m"  # 绿色
  else
      tmux_status="\e[90m未开服\e[0m"  # 灰色
  fi

}

while true; do
clear
pal_install_status
echo -e "\033[93m      .            .  ."
echo "._  _.|.    , _ ._.| _|"
echo "[_)(_]| \/\/ (_)[  |(_]"
echo "|                      "
echo -e "\033[96m幻兽帕鲁开服一键脚本工具v1.0.2  by ming.sh\033[0m"
echo -e "\033[96m-输入\033[93mp\033[96m可快速启动此脚本-\033[0m"
echo -e "$container_status $tmux_status"
echo "------------------------"
echo "1. 安装幻兽帕鲁服务"
echo "2. 开启幻兽帕鲁服务"
echo "3. 关闭幻兽帕鲁服务"
echo "4. 重启幻兽帕鲁服务"
echo "------------------------"
echo "5. 查看服务器状态"
echo "6. 设置虚拟内存"
echo "------------------------"
echo "7. 导出游戏存档"
echo "8. 导入游戏存档"
echo "9. 定时备份游戏存档"
echo "------------------------"
echo "10. 修改游戏配置"
echo "------------------------"
echo "11. 更新幻兽帕鲁服务"
echo "12. 卸载幻兽帕鲁服务"
echo "------------------------"
echo "m. ming.sh 工具箱"
echo "------------------------"
echo "00. 脚本更新"
echo "------------------------"
echo "0. 退出脚本"
echo "------------------------"
read -r -p "请输入你的选择: " choice

case $choice in
  1)
    clear
    install_docker
    install tmux
    docker run -dit --name steamcmd -p 8255:8211/udp --restart=always cm2network/steamcmd
    docker exec -it steamcmd bash -c "/home/steam/steamcmd/steamcmd.sh +login anonymous +app_update 2394010 validate +quit"
    clear
    pal_start
    ;;

  2)
    clear
    docker start steamcmd > /dev/null 2>&1
    pal_start
    ;;

  3)
    clear
    tmux kill-session -t my1
    docker stop steamcmd > /dev/null 2>&1
    echo -e "\033[0;32m幻兽帕鲁服务已关闭\033[0m"
    ;;

  4)
    clear
    tmux kill-session -t my1
    docker restart steamcmd > /dev/null 2>&1
    pal_start
    ;;

  5)
    clear
    install btop
    clear
    btop
    ;;

  6)
            clear
            swap_used=$(free -m | awk 'NR==3{print $3}')
            swap_total=$(free -m | awk 'NR==3{print $2}')

            if [ "$swap_total" -eq 0 ]; then
              swap_percentage=0
            else
              swap_percentage=$((swap_used * 100 / swap_total))
            fi

            swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

            echo "当前虚拟内存: $swap_info"

            read -r -p "是否调整大小?(Y/N): " choice

            case "$choice" in
              [Yy])
                # 输入新的虚拟内存大小
                read -r -p "请输入虚拟内存大小MB: " new_swap

                # 获取当前系统中所有的 swap 分区
                swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

                # 遍历并删除所有的 swap 分区
                for partition in $swap_partitions; do
                  swapoff "$partition"
                  wipefs -a "$partition"  # 清除文件系统标识符
                  mkswap -f "$partition"
                  echo "已删除并重新创建 swap 分区: $partition"
                done

                # 确保 /swapfile 不再被使用
                swapoff /swapfile

                # 删除旧的 /swapfile
                rm -f /swapfile

                # 创建新的 swap 分区
                dd if=/dev/zero of=/swapfile bs=1M count="$new_swap"
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile

                if [ -f /etc/alpine-release ]; then
                    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
                    echo "nohup swapon /swapfile" >> /etc/local.d/swap.start
                    chmod +x /etc/local.d/swap.start
                    rc-update add local
                else
                    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
                fi

                echo "虚拟内存大小已调整为${new_swap}MB"
                ;;
              [Nn])
                echo "已取消"
                ;;
              *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
    ;;

  7)
    clear
    pal_export_world
    ;;
  8)
    clear
    pal_restore_world
    ;;

  9)
    clear
    echo "幻兽帕鲁游戏存档定时备份"
    echo "------------------------"
    echo "1. 每周备份       2. 每天备份       3. 每小时备份"
    echo "------------------------"
    read -r -p "请输入你的选择: " dingshi
    case $dingshi in
        1)
            pal_backup
            pal_set_backup_cron "0 0 * * 1"
            echo "每周一备份，已设置"

            ;;
        2)
            pal_backup
            pal_set_backup_cron "0 3 * * *"
            echo "每天凌晨3点备份，已设置"

            ;;
        3)
            pal_backup
            pal_set_backup_cron "0 * * * *"
            echo "每小时整点备份，已设置"

            ;;
        *)
            echo "已取消"
            ;;
    esac
    ;;

  10)
    clear
    tmux kill-session -t my1
    cd ~ && curl -sS -O "$UPSTREAM_PALWORLD_SETTINGS_URL"

    echo "配置游戏参数"
    echo "------------------------"
    read -r -p "设置加入的密码（回车默认无密码）: " server_password
    read -r -p "设置游戏难度: （1. 简单    2. 普通    3. 困难）:" Difficulty
      case $Difficulty in
        1)
            Difficulty=1
            ;;

        2)
            Difficulty=2
            ;;
        3)
            Difficulty=3
            ;;
        *)
            echo "-默认设置为普通难度"
            Difficulty=2
            ;;
      esac

    read -r -p "经验值倍率: （回车默认1倍）:" exp_rate
      ExpRate=${exp_rate:-1}
    read -r -p "死亡后掉落设置: （1. 掉落    2. 不掉落）:" DeathPenalty
      case $DeathPenalty in
        1)
            DeathPenalty=All
            ;;

        2)
            DeathPenalty=None
            ;;
        *)
            DeathPenalty=All
            echo "-默认设置为掉落"
            ;;
      esac

    read -r -p "设置pvp模式: （1. 开启    2. 关闭）:" pal_pvp

      case $pal_pvp in
        1)
            pal_pvp=True
            ;;
        2)
            pal_pvp=False
            ;;
        *)
            pal_pvp=False
            echo "-默认关闭pvp模式"
            ;;
      esac

    # 更新配置文件
    sed -i "s/ServerPassword=\"\"/ServerPassword=\"$server_password\"/" ~/PalWorldSettings.ini
    sed -i "s/Difficulty=2/Difficulty=$Difficulty/" ~/PalWorldSettings.ini
    sed -i "s/ExpRate=1.000000/ExpRate=$ExpRate/" ~/PalWorldSettings.ini
    sed -i "s/DeathPenalty=All/DeathPenalty=$DeathPenalty/" ~/PalWorldSettings.ini
    sed -i "s/bEnablePlayerToPlayerDamage=False/bEnablePlayerToPlayerDamage=$pal_pvp/" ~/PalWorldSettings.ini
    sed -i "s/bIsPvP=False/bIsPvP=$pal_pvp/" ~/PalWorldSettings.ini
    echo "------------------------"
    echo "配置文件已更新"

    docker exec -it steamcmd bash -c "rm -f /home/steam/Steam/steamapps/common/PalServer/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
    docker cp ~/PalWorldSettings.ini steamcmd:/home/steam/Steam/steamapps/common/PalServer/Pal/Saved/Config/LinuxServer/ > /dev/null 2>&1
    docker exec -it -u root steamcmd bash -c "chown -R steam:steam /home/steam/Steam/steamapps/common/PalServer/Pal/Saved/ && chmod -R u+rwX,g+rwX,o-rwx /home/steam/Steam/steamapps/common/PalServer/Pal/Saved/"
    rm -f ~/PalWorldSettings.ini
    echo -e "\033[0;32m游戏配置已导入\033[0m"
    docker restart steamcmd > /dev/null 2>&1
    pal_start
    ;;


  11)
    clear
    tmux kill-session -t my1
    docker restart steamcmd > /dev/null 2>&1
    docker exec -it steamcmd bash -c "/home/steam/steamcmd/steamcmd.sh +login anonymous +app_update 2394010 validate +quit"
    clear
    echo -e "\033[0;32m幻兽帕鲁已更新\033[0m"
    pal_start
    ;;

  12)
    clear
    docker rm -f steamcmd
    docker rmi -f cm2network/steamcmd
    ;;

  m)
    cd ~ || exit 1
    if command -v "$PROJECT_COMMAND" >/dev/null 2>&1; then
      "$PROJECT_COMMAND"
    else
      echo "未找到 ${PROJECT_COMMAND} 命令，请先按 ${PROJECT_REPO_URL} 的说明安装 ming.sh。"
    fi
    exit
    ;;

  00)
    clear
    echo "palworld.sh 自更新已禁用。请从 ${PROJECT_REPO_URL} 审阅后手动更新。"
    ;;


  0)
    clear
    exit
    ;;

  *)
    echo "无效的输入!"
    ;;
esac
    break_end
done
