#!/bin/bash
set -euxo pipefail

if [ ! -d "discourse-theme-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-theme-skeleton discourse-theme-skeleton
fi

if [ ! -d "discourse-plugin-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-plugin-skeleton discourse-plugin-skeleton
fi

REPO_NAME=$(basename -s '.git' $(git -C repo remote get-url origin))

if [ ! -f "repo/package.json" ]; then
  echo "{ \"name\": \"$REPO_NAME\", \"private\": true }" > repo/package.json
  (cd repo && yarn add eslint-config-discourse --dev)
fi

# Copy these files from skeleton if they do not already exist
if [ -f "plugin.rb" ]; then
  cp -vn discourse-plugin-skeleton/.eslintrc repo || true
  cp -vn discourse-plugin-skeleton/.prettierrc repo || true
  cp -vn discourse-plugin-skeleton/.gitignore repo || true
  cp -vn discourse-plugin-skeleton/.streerc repo || true
  cp -vn discourse-plugin-skeleton/.rubocop.yml repo || true
  cp -vn discourse-plugin-skeleton/Gemfile repo || true
  bundle
else # Theme
  cp -vn discourse-theme-skeleton/.eslintrc repo || true
  cp -vn discourse-theme-skeleton/.prettierrc repo || true
  cp -vn discourse-theme-skeleton/.gitignore repo || true
fi

if ! grep -q 'node_modules' repo/.gitignore; then
  echo "node_modules" >> repo/.gitignore
fi

