#!/bin/bash
set -euxo pipefail

# Helper functions and setup of jq
file_exists() {
  [ -f "$1" ]
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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

cd repo

if ! file_exists package.json; then
  echo "ERROR: 'package.json' is missing. Cannot proceed with conversion."
  exit 1
fi

if file_exists yarn.lock; then
  echo "Removing yarn.lock..."
  rm yarn.lock
fi

if file_exists package-lock.json; then
  echo "Removing package-lock.json..."
  rm package-lock.json
fi

echo "Replacing 'yarn' with 'pnpm' in package.json scripts..."
jq 'if has("scripts") then .scripts |= with_entries(.value |= gsub("yarn "; "pnpm ")) else . end' package.json > temp.json && mv temp.json package.json

echo "Updating devDependencies clause in package.json..."
jq '.devDependencies = (.devDependencies // {}) |
  .devDependencies *= {
  "@discourse/lint-configs": "2.3.1",
  "ember-template-lint": "6.1.0",
  "eslint": "9.19.0",
  "prettier": "2.8.8"
}' package.json > temp.json && mv temp.json package.json

echo "Updating engines clause in package.json..."
jq '.engines = (.engines // {}) |
  .engines *= {
  "node": ">= 18",
  "npm": "please-use-pnpm",
  "yarn": "please-use-pnpm",
  "pnpm": ">= 10"
}' package.json > temp.json && mv temp.json package.json

if ! file_exists .npmrc; then
  echo "Creating .npmrc..."
  echo -e "engine-strict = true\nauto-install-peers = false" > .npmrc
fi

echo "Installing dependencies with pnpm..."
pnpm install

echo "Updating README with pnpm"
for file in README.md README; do
  if [ -f "$file" ]; then
    echo "Replacing 'yarn' with 'pnpm' in $file..."
    sed -i '' 's/yarn/pnpm/g' "$file"
  fi
done

if [ -d ".husky" ]; then
  echo "Replacing 'yarn' with 'pnpm' in .husky directory..."
  find .husky -type f -exec sed -i '' 's/yarn/pnpm/g' {} +
fi

echo "Conversion complete!"
