#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tabby_dir="$root_dir/tabbyAPI"
patch_file="$root_dir/patches/tabbyapi-local.patch"
model_repo="TelperionAI/Qwen3.8-27B-EXL3-5.5bpw"
model_revision="af0c885473c466f0f9cf89dfb4d43d475635330c"
model_name="Qwen3.8-27B-EXL3-5.5bpw"
smoke_test=0
with_searxng=0

usage() {
  echo "Usage: ./setup.sh [--smoke-test] [--with-searxng]"
  echo
  echo "Run without an option to install the server."
  echo "Use --smoke-test to create local configuration without large downloads."
  echo "Use --with-searxng to configure the optional SearXNG container."
}

while (( $# )); do
  case "$1" in
    --smoke-test) smoke_test=1 ;;
    --with-searxng) with_searxng=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    python3 -c 'import secrets; print(secrets.token_hex(32))'
  fi
}

prepare_tabbyapi() {
  git -C "$root_dir" submodule update --init --recursive

  if git -C "$tabby_dir" apply --unidiff-zero --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "TabbyAPI local patch is already applied."
  elif git -C "$tabby_dir" apply --unidiff-zero --check "$patch_file"; then
    git -C "$tabby_dir" apply --unidiff-zero "$patch_file"
    echo "Applied the TabbyAPI local patch."
  else
    echo "The TabbyAPI patch does not apply to the pinned source revision." >&2
    exit 1
  fi
}

prepare_credentials() {
  local token_file="$root_dir/api_tokens.yml"
  local client_file="$root_dir/client_api_key"
  local api_key
  local admin_key
  local old_umask

  if [[ -s "$token_file" ]]; then
    api_key=$(awk '/^[[:space:]]*-[[:space:]]+/{print $2; exit}' "$token_file" | tr -d "\"'")
    if [[ -z "$api_key" ]]; then
      echo "Could not read an API key from $token_file." >&2
      exit 1
    fi
  elif [[ -s "$client_file" ]]; then
    api_key=$(tr -d '\r\n' < "$client_file")
    admin_key=$(generate_secret)
    old_umask=$(umask)
    umask 077
    printf 'api_key:\n- %s\nadmin_key: %s\n' "$api_key" "$admin_key" > "$token_file"
    umask "$old_umask"
    echo "Created api_tokens.yml from the existing client key."
  else
    api_key=$(generate_secret)
    admin_key=$(generate_secret)
    old_umask=$(umask)
    umask 077
    printf 'api_key:\n- %s\nadmin_key: %s\n' "$api_key" "$admin_key" > "$token_file"
    printf '%s\n' "$api_key" > "$client_file"
    umask "$old_umask"
    echo "Generated local API credentials."
  fi

  if [[ ! -s "$client_file" ]]; then
    old_umask=$(umask)
    umask 077
    printf '%s\n' "$api_key" > "$client_file"
    umask "$old_umask"
  elif [[ $(tr -d '\r\n' < "$client_file") != "$api_key" ]]; then
    echo "client_api_key does not match the first key in api_tokens.yml." >&2
    exit 1
  fi

  chmod 600 "$token_file" "$client_file"
}

prepare_searxng() {
  local settings_file="$root_dir/searxng/settings.yml"
  local settings_template="$root_dir/searxng/settings.example.yml"
  local secret
  local old_umask

  if [[ -s "$settings_file" ]]; then
    return
  fi

  secret=$(generate_secret)
  old_umask=$(umask)
  umask 077
  sed "s/REPLACE_WITH_RANDOM_SECRET/$secret/" "$settings_template" > "$settings_file"
  umask "$old_umask"
  echo "Generated the local SearXNG configuration."
}

render_local_files() {
  local escaped_root
  local service_output="$root_dir/run/qwen-tabbyapi.service"
  local opencode_output="$root_dir/run/opencode-provider.json"

  if [[ "$root_dir" =~ [[:space:]\&\|\"\\] ]]; then
    echo "Clone this repository to a path without spaces or shell metacharacters." >&2
    exit 1
  fi

  escaped_root=${root_dir//\//\\/}
  sed "s/@PROJECT_DIR@/$escaped_root/g" \
    "$root_dir/systemd/qwen-tabbyapi.service.in" > "$service_output"
  sed "s|REPLACE_WITH_PROJECT_PATH|$root_dir|g" \
    "$root_dir/opencode/provider.example.json" > "$opencode_output"
}

install_model() {
  local python_bin="$root_dir/.venv/bin/python"
  local model_path
  local model_link="$root_dir/models/$model_name"

  model_path=$("$python_bin" - "$model_repo" "$model_revision" <<'PY'
import sys
from huggingface_hub import snapshot_download

print(snapshot_download(repo_id=sys.argv[1], revision=sys.argv[2]))
PY
)

  if [[ -L "$model_link" ]]; then
    ln -sfn "$model_path" "$model_link"
  elif [[ -e "$model_link" ]]; then
    echo "$model_link exists and is not a symbolic link." >&2
    exit 1
  else
    ln -s "$model_path" "$model_link"
  fi
  echo "Linked the model from the Hugging Face cache."
}

install_service() {
  local source_file="$root_dir/run/qwen-tabbyapi.service"
  local target_file="$HOME/.config/systemd/user/qwen-tabbyapi.service"

  install -Dm644 "$source_file" "$target_file"
  systemctl --user daemon-reload
  echo "Installed the qwen-tabbyapi.service user service."
}

require_command git
require_command python3
if (( ! smoke_test )); then
  if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    echo "This setup supports Linux x86_64 and WSL2 x86_64 only." >&2
    exit 1
  fi
  require_command uv
  require_command nvidia-smi
  require_command curl
  require_command systemctl
  if (( with_searxng )); then
    require_command docker
  fi
fi

mkdir -p "$root_dir/logs" "$root_dir/models" "$root_dir/run"
prepare_tabbyapi
prepare_credentials
if (( with_searxng )); then
  prepare_searxng
fi
render_local_files

if (( smoke_test )); then
  python3 -m json.tool "$root_dir/run/opencode-provider.json" >/dev/null
  echo "Smoke test completed. The smoke test did not install dependencies, models, or services."
  exit 0
fi

uv sync --project "$root_dir" --frozen --python 3.12
"$root_dir/.venv/bin/python" - <<'PY'
import torch

if not torch.cuda.is_available():
    raise SystemExit("PyTorch cannot use the NVIDIA GPU.")
print(f"PyTorch {torch.__version__} can use {torch.cuda.get_device_name(0)}.")
PY
install_model
install_service

echo
echo "Setup completed. Start the server with ./start.sh."
if (( with_searxng )); then
  echo "Start both services with ./start.sh --with-searxng."
fi
echo "For OpenCode, merge run/opencode-provider.json into your OpenCode configuration."
