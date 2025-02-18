#!/bin/bash
set -euxo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

if [ ! -d "discourse-theme-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-theme-skeleton discourse-theme-skeleton
fi

if [ ! -d "discourse-plugin-skeleton" ]; then
  git clone --quiet --depth 1 https://github.com/discourse/discourse-plugin-skeleton discourse-plugin-skeleton
fi

if ! command_exists jq; then
  echo "jq is not installed. Attempting to install it..."
  if command_exists apt-get; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command_exists brew; then
    brew install jq
  else
    echo "Error: Cannot install jq. Please install it manually and run this script again."
    exit 1
  fi
fi

if [ ! -f repo/package.json ]; then
  echo "Initializing package.json..."
  echo '{}' > repo/package.json
fi

# Use the current js linting setup
echo "Updating linting dependencies setup in package.json..."
jq '.private = true |
  .devDependencies = (.devDependencies // {}) |
  .devDependencies *= {
    "@discourse/lint-configs": "2.5.0",
    "ember-template-lint": "6.1.0",
    "eslint": "9.19.0",
    "prettier": "2.8.8",
    "stylelint": "16.14.1"
  } |
  del(.devDependencies["@babel/plugin-proposal-decorators"]) |
  .engines = (.engines // {}) |
  .engines *= {
    "node": ">= 22",
    "npm": "please-use-pnpm",
    "yarn": "please-use-pnpm",
    "pnpm": "9.x"
  } |
  .packageManager = "pnpm@9.15.5"
' repo/package.json > repo/temp.json

mv repo/temp.json repo/package.json

# Copy these files from skeleton if they do not already exist
if [ -f "repo/plugin.rb" ]; then
  cp -vn discourse-plugin-skeleton/.gitignore repo || true
else # Theme
  cp -vn discourse-theme-skeleton/.gitignore repo || true
fi

if ! grep -q 'node_modules' repo/.gitignore; then
  echo "node_modules" >> repo/.gitignore
fi
