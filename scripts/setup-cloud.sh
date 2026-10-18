#!/usr/bin/env bash
set -euo pipefail
mkdir -p /workspace/toolchains /workspace/.cache/finance
export npm_config_cache=/workspace/.cache/finance/npm
if [[ ! -x /workspace/toolchains/go/bin/go ]]; then
  task_archive="$(mktemp /tmp/finance-go.XXXXXX.tar.gz)"
  curl --fail --silent --show-error --location https://go.dev/dl/go1.27.2.linux-amd64.tar.gz -o "$task_archive"
  printf '%s  %s\n' ecbadb99091a3f46e31f5f934b068b1864eafa7995211b39eaddf76996045fe5 "$task_archive" | sha256sum --check -
  tar -xzf "$task_archive" -C /workspace/toolchains
  rm "$task_archive"
fi
if [[ "$(/workspace/toolchains/go/bin/go version)" != 'go version go1.27.2 linux/amd64' ]]; then
  echo 'Unexpected Go toolchain; preserve it and resolve the version before continuing.' >&2
  exit 1
fi
if [[ ! -d /workspace/toolchains/flutter ]]; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /workspace/toolchains/flutter
fi
if [[ "$(git -C /workspace/toolchains/flutter rev-parse HEAD)" != abaf9c523780a608bd46686fd5e53740a07077f8 ]]; then
  echo 'Unexpected Flutter checkout; preserve it and resolve the version before continuing.' >&2
  exit 1
fi
source /workspace/finance-tracker/scripts/cloud-env.sh
node --version
npm --version
flutter --version
(cd /workspace/finance-tracker/web && npm ci --no-audit --no-fund && npm run build)
(cd /workspace/finance-tracker/backend && go test -race ./... && go build -o /workspace/.cache/finance/api .)
(cd /workspace/finance-tracker/mobile && flutter pub get --enforce-lockfile && flutter analyze && flutter test)
