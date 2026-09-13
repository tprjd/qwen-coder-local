#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root_dir/scripts/common.sh"
log_file="$root_dir/logs/tabbyapi.log"
with_searxng=0

usage() {
  echo "Usage: ./start.sh [--with-searxng]"
  echo
  echo "Start TabbyAPI alone by default."
  echo "Use --with-searxng to also start the optional SearXNG container."
}

if (( $# > 1 )); then
  usage >&2
  exit 2
fi
if (( $# == 1 )); then
  case "$1" in
    --with-searxng) with_searxng=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
fi

mkdir -p "$root_dir/run" "$root_dir/logs"
chmod 700 "$root_dir/run" "$root_dir/logs"

if (( with_searxng )); then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required for SearXNG." >&2
    exit 1
  fi
  if [[ ! -f "$root_dir/searxng/settings.yml" ]]; then
    echo "Missing searxng/settings.yml. Run ./setup.sh --with-searxng first." >&2
    exit 1
  fi

  if docker ps -a --filter "name=^searxng$" --format '{{.Names}}' | grep -q .; then
    if ! searxng_container_matches_project; then
      echo "The existing SearXNG container does not match the safe pinned configuration." >&2
      echo "Run ./stop.sh, docker rm searxng, and ./start.sh --with-searxng to recreate it." >&2
      exit 1
    fi
    if docker ps --filter "name=^searxng$" --filter status=running --format '{{.Names}}' | grep -q .; then
      echo "SearXNG is already running."
    else
      docker start searxng >/dev/null
      echo "SearXNG started."
    fi
  else
    docker run -d --name searxng -p 127.0.0.1:8888:8080 \
      -v "$root_dir/searxng/settings.yml":/etc/searxng/settings.yml:ro \
      "$searxng_image" >/dev/null
    echo "SearXNG created and started."
  fi

  searxng_ready=0
  for _ in $(seq 1 30); do
    if curl --silent --fail --max-time 2 http://127.0.0.1:8888/config >/dev/null; then
      searxng_ready=1
      break
    fi
    sleep 1
  done
  if (( searxng_ready )); then
    echo "SearXNG is ready at http://127.0.0.1:8888"
  else
    echo "SearXNG is not responding yet. Check: docker logs searxng" >&2
  fi
fi

if systemctl --user is-active --quiet qwen-tabbyapi.service; then
  echo "TabbyAPI is already running."
  exit 0
fi

if ss -ltn 'sport = :5000' | tail -n +2 | grep -q .; then
  echo "Port 5000 is already in use. Refusing to start." >&2
  exit 1
fi

if [[ ! -x "$root_dir/.venv/bin/python" ]]; then
  echo "Missing virtual environment at $root_dir/.venv." >&2
  exit 1
fi

umask 077
touch "$log_file"
chmod 600 "$log_file"
systemctl --user daemon-reload
systemctl --user start qwen-tabbyapi.service

echo "Starting TabbyAPI. Model loading can take several minutes."
for _ in $(seq 1 600); do
  if ! systemctl --user is-active --quiet qwen-tabbyapi.service; then
    echo "TabbyAPI exited during startup. Recent log output:" >&2
    tail -n 60 "$log_file" >&2
    exit 1
  fi
  if curl --silent --fail --max-time 2 http://127.0.0.1:5000/health >/dev/null; then
    echo "TabbyAPI is ready at http://127.0.0.1:5000/v1"
    exit 0
  fi
  sleep 1
done

echo "TabbyAPI is still loading. Check $log_file and run ./status.sh." >&2
exit 1
