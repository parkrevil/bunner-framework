#!/usr/bin/env bash
set -euo pipefail

OWNER="${BUNNER_OWNER:-parkrevil}"
BRANCH="${BUNNER_BRANCH:-main}"

repos=(
  bunner
  bunner-agentops
  bunner-cli
  bunner-common
  bunner-core
  bunner-example
  bunner-firebat
  bunner-http-adapter
  bunner-logger
  bunner-oxlint-plugin
  bunner-scalar
  bunner-shared
)

clone_one() {
  local repo="$1"
  local dir="$repo"
  local url="https://github.com/${OWNER}/${repo}.git"

  if [ -d "$dir/.git" ]; then
    echo "SKIP (exists): $dir"
    return 0
  fi

  echo "CLONE: $url -> $dir"
  git clone --branch "$BRANCH" "$url" "$dir"
}

for r in "${repos[@]}"; do
  clone_one "$r"
done

echo "DONE"
