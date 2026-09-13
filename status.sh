#!/usr/bin/env bash
set -u

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root_dir/scripts/common.sh"

if systemctl --user is-active --quiet qwen-tabbyapi.service; then
  server_pid=$(systemctl --user show qwen-tabbyapi.service --property=MainPID --value)
  echo "TabbyAPI process: running, PID $server_pid"
else
  echo "TabbyAPI process: stopped"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "SearXNG: unavailable because Docker is not installed"
elif docker ps --filter "name=^searxng$" --filter status=running --format '{{.Names}}' | grep -q .; then
  if searxng_container_matches_project; then
    echo "SearXNG: running at http://127.0.0.1:8888"
  else
    echo "SearXNG: running with a configuration mismatch"
    echo "Recreate this container with ./stop.sh, docker rm searxng, and ./start.sh --with-searxng."
  fi
else
  echo "SearXNG: not running (optional)"
fi

if curl --silent --fail --max-time 2 "$tabby_api_base_url/health"; then
  echo
else
  echo "API health: unavailable"
fi

if [[ -x "$python_bin" && -f "$auth_file" ]]; then
  api_key=$(read_api_key 2>/dev/null)
  curl --silent --fail --max-time 3 \
    -H "Authorization: Bearer $api_key" \
    "$tabby_api_base_url/v1/models" 2>/dev/null || true
  echo
fi

nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw \
  --format=csv,noheader
