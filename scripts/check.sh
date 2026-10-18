#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x /workspace/toolchains/go/bin/go ]]; then export PATH="/workspace/toolchains/go/bin:$PATH"; fi
if [[ -x /workspace/toolchains/flutter/bin/flutter ]]; then export PATH="/workspace/toolchains/flutter/bin:$PATH"; fi
export GOCACHE="${GOCACHE:-/workspace/.cache/finance/go}"
export PUB_CACHE="${PUB_CACHE:-/workspace/.cache/finance/pub}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.cache/finance/config}"
export ANALYZER_STATE_LOCATION_OVERRIDE="${ANALYZER_STATE_LOCATION_OVERRIDE:-/workspace/.cache/finance/analyzer}"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
(cd "$repo_dir/backend" && go test -race ./... && go build -o "${TMPDIR:-/tmp}/finance-tracker-api" .)
(cd "$repo_dir/web" && npm run build && npm run typecheck)
(cd "$repo_dir/mobile" && flutter analyze && flutter test)
