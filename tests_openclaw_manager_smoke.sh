#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$REPO_DIR/ming.sh"
WORKDIR=$(mktemp -d "$REPO_DIR/.openclaw-manager-test.XXXXXX")
mkdir -p "$WORKDIR/bin" "$WORKDIR/home/.openclaw" "$WORKDIR/web/conf.d"
cleanup() {
  [ "${BASH_SUBSHELL:-0}" -eq 0 ] || return 0
  rm -rf -- "$WORKDIR"
}
trap cleanup EXIT

extract_between() {
  local start_marker="$1"
  local end_marker="$2"
  awk -v start_marker="$start_marker" -v end_marker="$end_marker" '
    index($0, start_marker) {
      found_start = 1
    }
    found_start && index($0, end_marker) {
      found_end = 1
      exit
    }
    found_start {
      print
    }
    END {
      if (!found_start || !found_end) {
        exit 1
      }
    }
  ' "$SCRIPT"
}

cat > "$WORKDIR/harness.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
install() { return 0; }
break_end() { :; }
openclaw_get_config_file() { printf '%s\n' "$HOME/.openclaw/openclaw.json"; }
gh_proxy=""
: "${OPENCLAW_TEST_WEB_CONF_DIR:?}"
EOF
extract_between \
  'build-openclaw-provider-models-json() {' \
  'add-default-model-only-to-provider() {' >> "$WORKDIR/harness.sh"
printf '\n' >> "$WORKDIR/harness.sh"
extract_between \
  'openclaw_memory_config_file() {' \
  'openclaw_memory_auto_setup_menu() {' >> "$WORKDIR/harness.sh"
printf '\n' >> "$WORKDIR/harness.sh"
extract_between \
  'openclaw_find_webui_domain() {' \
  'openclaw_domain_webui() {' |
  sed 's#/home/web/conf.d/#"${OPENCLAW_TEST_WEB_CONF_DIR}"/#g' >> "$WORKDIR/harness.sh"
printf '\n' >> "$WORKDIR/harness.sh"
chmod +x "$WORKDIR/harness.sh"

cat > "$WORKDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "-I" ]; then
    exit 0
  fi
done
if [[ "$*" == *"/models"* ]]; then
  cat <<JSON
{"data":[{"id":"gpt-5.4"},{"id":"gpt-5.3-codex"},{"id":"claude-opus-4-6-thinking"}]}
JSON
else
  echo "US"
fi
EOF
chmod +x "$WORKDIR/bin/curl"

cat > "$WORKDIR/bin/grep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "-oP" ]; then
  shift 2
  /usr/bin/awk -F'"id"[[:space:]]*:[[:space:]]*"' '{
    for (i = 2; i <= NF; i++) {
      split($i, value, "\"")
      print value[1]
    }
  }' "$@"
  exit 0
fi
exec /usr/bin/grep "$@"
EOF
chmod +x "$WORKDIR/bin/grep"

cat > "$WORKDIR/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
log_file="$HOME/.openclaw/mock_openclaw.log"
echo "openclaw $cmd $*" >> "$log_file"
case "$cmd" in
  dashboard)
    echo "Dashboard: http://127.0.0.1:18789/#token=deadbeef"
    ;;
  config)
    sub="${1:-}"
    shift || true
    config_file="$HOME/.openclaw/mock_config.env"
    touch "$config_file"
    case "$sub" in
      set)
        key="$1"
        shift || true
        value="$*"
        grep -v "^${key}=" "$config_file" > "${config_file}.tmp" || true
        echo "${key}=${value}" >> "${config_file}.tmp"
        mv "${config_file}.tmp" "$config_file"
        ;;
      get)
        key="$1"
        if grep -q "^${key}=" "$config_file"; then
          awk -F'=' -v k="$key" '$1==k {print substr($0, index($0, "=")+1); exit}' "$config_file"
        fi
        ;;
      unset)
        key="$1"
        grep -v "^${key}=" "$config_file" > "${config_file}.tmp" || true
        mv "${config_file}.tmp" "$config_file"
        ;;
      *)
        echo "mock openclaw config $sub $*"
        ;;
    esac
    ;;
  memory)
    sub="${1:-}"
    shift || true
    case "$sub" in
      status)
        if [ "${1:-}" = "--json" ]; then
          cat <<JSON
[
  {
    "agentId": "main",
    "status": {
      "backend": "builtin",
      "files": 0,
      "chunks": 0,
      "dirty": false,
      "vector": {"enabled": true, "available": true},
      "workspaceDir": "$HOME/.openclaw/workspace",
      "dbPath": "$HOME/.openclaw/workspace/memory/index.sqlite"
    },
    "scan": {"issues": []}
  }
]
JSON
        else
          echo "Provider: builtin"
          echo "Vector: ok"
          echo "Indexed: 0/0"
          echo "Workspace: $HOME/.openclaw/workspace"
        fi
        ;;
      index)
        echo "mock memory index $*"
        ;;
      *)
        echo "mock openclaw memory $sub $*"
        ;;
    esac
    ;;
  gateway)
    sub="${1:-}"
    shift || true
    if [ "$sub" = "restart" ]; then
      echo "mock gateway restart"
    else
      echo "mock openclaw gateway $sub $*"
    fi
    ;;
  *)
    echo "mock openclaw $cmd $*"
    ;;
esac
EOF
chmod +x "$WORKDIR/bin/openclaw"

export HOME="$WORKDIR/home"
export OPENCLAW_TEST_WEB_CONF_DIR="$WORKDIR/web/conf.d"
for required_tool in jq python3; do
  required_path=$(command -v "$required_tool") || {
    echo "missing required test tool: $required_tool" >&2
    exit 1
  }
  ln -s "$required_path" "$WORKDIR/bin/$required_tool"
done
export PATH="$WORKDIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cat > "$HOME/.openclaw/openclaw.json" <<'JSON'
{"models":{"mode":"merge","providers":{}}}
JSON

cat > "$OPENCLAW_TEST_WEB_CONF_DIR/test-openclaw.conf" <<'EOF'
server {
  listen 443 ssl;
  server_name claw.example.com;
  location / {
    proxy_pass http://127.0.0.1:18789;
  }
}
EOF

source "$WORKDIR/harness.sh"

echo '[TEST] add-all-models-from-provider'
add-all-models-from-provider "cli-api" "https://example.com/v1" "dummy-token" >"$WORKDIR/add-models.out"
jq -e '.models.providers["cli-api"].models | length == 3' "$HOME/.openclaw/openclaw.json" >/dev/null
jq -r '.models.providers["cli-api"].models[].id' "$HOME/.openclaw/openclaw.json"

echo '[TEST] openclaw_find_webui_domain'
openclaw_find_webui_domain

echo '[TEST] openclaw_show_webui_addr'
openclaw_show_webui_addr

echo '[TEST] openclaw_memory_auto_setup_run local'
mkdir -p "$HOME/.openclaw/models/embedding"
touch "$HOME/.openclaw/models/embedding/embeddinggemma-300M-Q8_0.gguf"
echo "memory.local=legacy" > "$HOME/.openclaw/mock_config.env"
openclaw_memory_auto_setup_run "local" <<< "yes" >"$WORKDIR/memory-auto.out"

grep -q '^memory.backend=builtin' "$HOME/.openclaw/mock_config.env"
grep -q '^agents.defaults.memorySearch.provider=local' "$HOME/.openclaw/mock_config.env"
if grep -q '^memory.local=' "$HOME/.openclaw/mock_config.env"; then
  echo "memory.local should be removed"
  exit 1
fi

grep -Eq 'openclaw memory index .*--force' "$HOME/.openclaw/mock_openclaw.log"
grep -q 'openclaw gateway restart' "$HOME/.openclaw/mock_openclaw.log"

cleanup
trap - EXIT
echo 'SMOKE_OK'
