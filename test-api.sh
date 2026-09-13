#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root_dir/scripts/common.sh"

if [[ ! -f "$auth_file" ]]; then
  echo "Missing $auth_file. Start the server once to generate it." >&2
  exit 1
fi

api_key=$(read_api_key)

curl --silent --show-error --fail "$tabby_api_base_url/v1/chat/completions" \
  -H "Authorization: Bearer $api_key" \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON'
{
  "model": "Qwen3.8-27B-EXL3-5.5bpw",
  "messages": [
    {"role": "user", "content": "Reply with exactly: local inference works"}
  ],
  "reasoning_effort": "low",
  "max_tokens": 128,
  "temperature": 1.0,
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0.0,
  "presence_penalty": 0.0,
  "repetition_penalty": 1.0
}
JSON
echo
