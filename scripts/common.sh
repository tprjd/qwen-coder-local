#!/usr/bin/env bash

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python_bin="$project_root/.venv/bin/python"
auth_file="$project_root/api_tokens.yml"
tabby_api_base_url="http://127.0.0.1:5000"
searxng_image="searxng/searxng@sha256:11a9b34cdc0b1ec2b991470a2762ecb5a1a531898289fb51dcd015260450729e"

searxng_container_matches_project() {
  local configured_image
  local mounted_settings
  local mount_is_writable
  local network_mode
  local published_ports

  configured_image=$(docker inspect --format '{{.Config.Image}}' searxng 2>/dev/null)
  published_ports=$(docker port searxng 8080/tcp 2>/dev/null)
  mounted_settings=$(docker inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/etc/searxng/settings.yml"}}{{.Source}}{{end}}{{end}}' \
    searxng 2>/dev/null)
  mount_is_writable=$(docker inspect --format \
    '{{range .Mounts}}{{if eq .Destination "/etc/searxng/settings.yml"}}{{.RW}}{{end}}{{end}}' \
    searxng 2>/dev/null)
  network_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' searxng 2>/dev/null)

  [[ "$configured_image" == "$searxng_image" \
    && "$published_ports" == "127.0.0.1:8888" \
    && "$mounted_settings" == "$project_root/searxng/settings.yml" \
    && "$mount_is_writable" == false \
    && "$network_mode" == bridge ]]
}

read_api_key() {
  "$python_bin" - "$auth_file" <<'PY'
import sys
from ruamel.yaml import YAML

with open(sys.argv[1], encoding="utf-8") as token_file:
    print(YAML(typ="safe").load(token_file)["api_key"][0])
PY
}
