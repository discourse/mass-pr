#!/bin/bash
set -euxo pipefail

if [ ! -d "discourse-theme-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-theme-skeleton discourse-theme-skeleton
fi

if [ ! -d "discourse-plugin-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-plugin-skeleton discourse-plugin-skeleton
fi

# Use the current js linting setup
REPO_NAME=$(basename -s '.git' $(git -C repo remote get-url origin))
echo '{
  "name": "'$REPO_NAME'",
  "private": true,
  "devDependencies": {
    "@discourse/lint-configs": "^1.3.5",
    "ember-template-lint": "^5.13.0",
    "eslint": "^8.56.0",
    "prettier": "^2.8.8"
  }
}' > repo/package.json

# Copy these files from skeleton if they do not already exist
if [ -f "repo/plugin.rb" ]; then
  cp -vn discourse-plugin-skeleton/.gitignore repo || true
else # Theme
  cp -vn discourse-theme-skeleton/.gitignore repo || true
fi

if ! grep -q 'node_modules' repo/.gitignore; then
  echo "node_modules" >> repo/.gitignore
fi
