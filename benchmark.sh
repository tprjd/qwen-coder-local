#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$root_dir/scripts/common.sh"
runs=${1:-3}

api_key=$(read_api_key)

for run_number in $(seq 1 "$runs"); do
  echo "Run $run_number of $runs"
  curl --silent --show-error --fail "$tabby_api_base_url/v1/chat/completions" \
    -H "Authorization: Bearer $api_key" \
    -H 'Content-Type: application/json' \
    --data-binary @- <<'JSON'
{
  "model": "Qwen3.8-27B-EXL3-5.5bpw",
  "messages": [
    {"role": "user", "content": "Write a correct Python function named merge_sorted that merges two sorted integer lists. Return only the code."}
  ],
  "reasoning_effort": "medium",
  "max_tokens": 512,
  "temperature": 1.0,
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0.0,
  "presence_penalty": 0.0,
  "repetition_penalty": 1.0
}
JSON
  echo
done
