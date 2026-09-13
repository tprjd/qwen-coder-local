#!/usr/bin/env bash
set -euo pipefail

if docker ps -a --filter "name=^searxng$" --format '{{.Names}}' | grep -q .; then
  docker stop searxng >/dev/null
  echo "SearXNG stopped."
fi

if ! systemctl --user is-active --quiet qwen-tabbyapi.service; then
  echo "TabbyAPI is not running."
else
  systemctl --user stop qwen-tabbyapi.service
  echo "TabbyAPI stopped cleanly."
fi
