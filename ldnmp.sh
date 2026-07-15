#!/bin/bash
project_script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
if [ -r "$project_script_dir/config/project.conf" ]; then
	# shellcheck disable=SC1091
	. "$project_script_dir/config/project.conf"
fi
unset project_script_dir
UPSTREAM_DOCKER_RAW_BASE="${UPSTREAM_DOCKER_RAW_BASE:-https://raw.githubusercontent.com/kejilion/docker/main}"
UPSTREAM_DOCKER_DOWNLOAD_BASE="${UPSTREAM_DOCKER_DOWNLOAD_BASE:-$UPSTREAM_DOCKER_RAW_BASE}"
UPSTREAM_DB_USER_PLACEHOLDER="${UPSTREAM_DB_USER_PLACEHOLDER:-kejilion}"
UPSTREAM_DB_PASSWORD_PLACEHOLDER="${UPSTREAM_DB_PASSWORD_PLACEHOLDER:-kejilionYYDS}"

run_reviewed_remote_script() {
	local script_url="$1"
	shift
	local cache_dir script_path exit_status
	case "$script_url" in https://*) ;; *) echo "拒绝非 HTTPS 脚本: $script_url"; return 1 ;; esac
	cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/ming-sh/remote-scripts"
	[ ! -L "$cache_dir" ] || { echo "拒绝符号链接缓存目录。"; return 1; }
	mkdir -p -- "$cache_dir" && chmod 0700 "$cache_dir" || return 1
	[ -O "$cache_dir" ] || { echo "缓存目录不属于当前用户。"; return 1; }
	script_path=$(mktemp "$cache_dir/review.XXXXXX.sh") || return 1
	chmod 0600 "$script_path"
	if command -v curl >/dev/null 2>&1; then
		curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 --output "$script_path" "$script_url" || { rm -f -- "$script_path"; return 1; }
	elif command -v wget >/dev/null 2>&1; then
		wget --https-only --secure-protocol=TLSv1_2 -qO "$script_path" "$script_url" || { rm -f -- "$script_path"; return 1; }
	else
		echo "需要 curl 或 wget 才能下载脚本。"
		rm -f -- "$script_path"
		return 1
	fi
	[ -s "$script_path" ] || { echo "下载结果为空。"; rm -f -- "$script_path"; return 1; }
	bash -n "$script_path" || { echo "远程脚本语法检查失败: $script_path"; rm -f -- "$script_path"; return 1; }
	printf '远程脚本已通过 HTTPS 下载和 Bash 语法检查，正在自动执行。\n来源: %s\n' "$script_url"
	bash "$script_path" "$@"
	exit_status=$?
	rm -f -- "$script_path"
	return "$exit_status"
}

# 获取用户输入，用于替换 docker-compose.yml 文件中的占位符
read -r -s -p "请输入 数据库ROOT密码：" dbrootpasswd
echo
read -r -p "请输入 数据库用户名：" dbuse
read -r -s -p "请输入 数据库用户密码：" dbusepasswd
echo


# 更新并安装必要的软件包
DEBIAN_FRONTEND=noninteractive apt update -y
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
apt install -y curl wget sudo socat unzip tar htop

# 安装 Docker
run_reviewed_remote_script https://get.docker.com

# 安装 Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

# 创建必要的目录和文件
cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis && touch web/docker-compose.yml

# 下载 docker-compose.yml 文件并进行替换
wget -O /home/web/docker-compose.yml "${UPSTREAM_DOCKER_DOWNLOAD_BASE}/LNMP-docker-compose-4.yml"


# 在 docker-compose.yml 文件中进行替换
sed -i "s/webroot/$dbrootpasswd/g" /home/web/docker-compose.yml
sed -i "s/${UPSTREAM_DB_PASSWORD_PLACEHOLDER}/$dbusepasswd/g" /home/web/docker-compose.yml
sed -i "s/${UPSTREAM_DB_USER_PLACEHOLDER}/$dbuse/g" /home/web/docker-compose.yml

cd /home/web && docker-compose up -d

docker exec php apt update &&
docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick &&
docker exec php docker-php-ext-install mysqli pdo_mysql zip exif gd intl bcmath opcache &&
docker exec php pecl install imagick &&
docker exec php sh -c 'echo "extension=imagick.so" > /usr/local/etc/php/conf.d/imagick.ini' &&
docker exec php pecl install redis &&
docker exec php sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' &&
docker exec php sh -c 'echo "upload_max_filesize=50M \n post_max_size=50M" > /usr/local/etc/php/conf.d/uploads.ini' &&
docker exec php sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini'


docker exec php74 apt update &&
docker exec php74 apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick &&
docker exec php74 docker-php-ext-install mysqli pdo_mysql zip gd intl bcmath opcache &&
docker exec php74 pecl install imagick &&
docker exec php74 sh -c 'echo "extension=imagick.so" > /usr/local/etc/php/conf.d/imagick.ini' &&
docker exec php74 pecl install redis &&
docker exec php74 sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' &&
docker exec php74 sh -c 'echo "upload_max_filesize=50M \n post_max_size=50M" > /usr/local/etc/php/conf.d/uploads.ini' &&
docker exec php74 sh -c 'echo "memory_limit=256M" > /usr/local/etc/php/conf.d/memory.ini'
