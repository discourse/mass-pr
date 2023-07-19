#!/bin/bash
set -exo pipefail

echo "hello" 
cd repo

if [[ -z "${CORE_VERSION}" ]]; then
  echo "CORE_VERSION environment variable must be set"
  exit 1
fi

CURRENT_PLUGIN_MAIN_HASH=$(git rev-parse HEAD)

if [ ! -f ".discourse-compatibility" ]; then
  echo "" > .discourse-compatibility
fi

PREPEND_LINE="$CORE_VERSION: $CURRENT_PLUGIN_MAIN_HASH"

echo -e "$PREPEND_LINE\\n$(cat .discourse-compatibility)" > .discourse-compatibility

