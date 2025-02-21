#!/bin/bash
set -euxo pipefail

if [ ! -d "discourse-theme-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-theme-skeleton discourse-theme-skeleton
fi

if [ ! -d "discourse-plugin-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-plugin-skeleton discourse-plugin-skeleton
fi

REPO_NAME=$(basename -s '.git' $(git -C repo remote get-url origin))

# Copy LICENSE from skeleton
if [ -f "repo/plugin.rb" ]; then
  cp -v discourse-plugin-skeleton/LICENSE repo || true
else # Theme
  cp -v discourse-theme-skeleton/LICENSE repo || true
fi
