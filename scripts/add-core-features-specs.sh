#!/bin/bash
set -euxo pipefail

cd repo

# Copy these files from skeleton if they do not already exist
mkdir -p spec/system || true
if [ -f "plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/spec/system/core_features_spec.rb spec/system || true
else # Theme
  cp -vn ../discourse-theme-skeleton/spec/system/core_features_spec.rb spec/system || true
fi

cd ..
