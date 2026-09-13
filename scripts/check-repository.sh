#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root_dir"

fail() {
  echo "Repository check failed: $1" >&2
  exit 1
}

for path in .venv api_tokens.yml client_api_key searxng/settings.yml; do
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    fail "$path contains local state and must not be tracked"
  fi
done

unexpected_runtime_files=$(git ls-files logs models run \
  | grep -Ev '^(logs|models|run)/\.gitkeep$' || true)
if [[ -n "$unexpected_runtime_files" ]]; then
  echo "$unexpected_runtime_files" >&2
  fail "Git tracks generated runtime files"
fi

home_path_pattern='/'"home/[^/]+/"
if git grep -n -E "$home_path_pattern" -- ':!patches/**' >/dev/null; then
  git grep -n -E "$home_path_pattern" -- ':!patches/**' >&2
  fail "a tracked file contains a fixed home-directory path"
fi

if [[ $(git ls-files --stage tabbyAPI | awk '{print $1}') != 160000 ]]; then
  fail "Git does not record tabbyAPI as a submodule"
fi

patch_file="$root_dir/patches/tabbyapi-local.patch"
if ! git -C tabbyAPI apply --unidiff-zero --check "$patch_file" >/dev/null 2>&1 \
  && ! git -C tabbyAPI apply --unidiff-zero --reverse --check "$patch_file" >/dev/null 2>&1; then
  fail "the TabbyAPI patch does not match the pinned revision"
fi

for script in setup.sh start.sh stop.sh status.sh benchmark.sh test-api.sh scripts/common.sh scripts/check-repository.sh; do
  bash -n "$script"
done

python3 -m json.tool opencode/provider.example.json >/dev/null
if ! grep -q 'REPLACE_WITH_RANDOM_SECRET' searxng/settings.example.yml; then
  fail "the SearXNG template does not contain its secret placeholder"
fi
if ! grep -q 'searxng/searxng@sha256:' scripts/common.sh; then
  fail "scripts/common.sh does not pin the SearXNG image by digest"
fi

echo "Repository check passed."
