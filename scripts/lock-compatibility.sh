#!/bin/bash
# Adds an entry to `.discourse-compatibility` which pins the specified core version (via `CORE_VERSION` environment variable)
# to the plugin/theme's current main branch commit hash

set -exo pipefail

cd repo

if [[ -z "${CORE_VERSION}" ]]; then
  echo "CORE_VERSION environment variable must be set"
  exit 1
fi

CURRENT_PLUGIN_MAIN_HASH=$(git rev-parse HEAD)

if [ ! -f ".discourse-compatibility" ]; then
  touch .discourse-compatibility
fi

if grep -q "$CORE_VERSION" ".discourse-compatibility"; then
  echo "Plugin already has a discourse-compatibility entry for this version. Skipping"
  exit 0
fi

PREPEND_LINE="$CORE_VERSION: $CURRENT_PLUGIN_MAIN_HASH"

echo -e "$PREPEND_LINE\\n$(cat .discourse-compatibility)" > .discourse-compatibility
