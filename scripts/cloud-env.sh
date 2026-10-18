# Source this file in cloud-task shells; each shell needs its own activation.
export PATH="/workspace/toolchains/go/bin:/workspace/toolchains/flutter/bin:$PATH"
export GOCACHE=/workspace/.cache/finance/go
export PUB_CACHE=/workspace/.cache/finance/pub
export npm_config_cache=/workspace/.cache/finance/npm
export XDG_CONFIG_HOME=/workspace/.cache/finance/config
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.cache/finance/analyzer
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
