#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
settings_file="$root_dir/searxng/settings.yml"
created_settings=0

cleanup() {
  rm -r -- "$test_dir"
  if (( created_settings )); then
    rm -f -- "$settings_file"
  fi
}
trap cleanup EXIT
export test_docker_log="$test_dir/docker.log"

docker() {
  printf '%s\n' "$*" >> "$test_docker_log"
}

systemctl() {
  return 0
}

curl() {
  return 0
}

export -f docker systemctl curl

: > "$test_docker_log"
"$root_dir/start.sh" >/dev/null
if [[ -s "$test_docker_log" ]]; then
  echo "start.sh called Docker without --with-searxng." >&2
  exit 1
fi

if [[ ! -e "$settings_file" ]]; then
  printf 'server:\n  secret_key: test-only\n' > "$settings_file"
  created_settings=1
fi

: > "$test_docker_log"
"$root_dir/start.sh" --with-searxng >/dev/null
if [[ ! -s "$test_docker_log" ]]; then
  echo "start.sh did not call Docker with --with-searxng." >&2
  exit 1
fi

setup_help=$("$root_dir/setup.sh" --help)
if ! grep -q -- '--with-searxng' <<< "$setup_help"; then
  echo "setup.sh does not document --with-searxng." >&2
  exit 1
fi

echo "Optional SearXNG command test passed."
