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

echo "Updating engines clause in package.json..."
jq '.engines = (.engines // {}) |
  .engines *= {
  "node": ">= 18",
  "npm": "please-use-pnpm",
  "yarn": "please-use-pnpm",
  "pnpm": ">= 9"
}' package.json > temp.json && mv temp.json package.json

if ! file_exists .pnpmfile.cjs; then
  echo "Adding .pnpmfile hook to clean up yarn managed node_modules..."
  cat << 'EOF' > .pnpmfile.cjs
const fs = require("fs");
const { execSync } = require("child_process");

const currRoot = __dirname;

if (fs.existsSync(`${currRoot}/node_modules/.yarn-integrity`)) {
  console.log(
    "Detected yarn-managed node_modules. Performing one-time cleanup..."
  );

  // Delete entire contents of all node_modules directories
  // But keep the directories themselves, in case they are volume mounts (e.g. in devcontainer)
  execSync(
    `find ${currRoot}/node_modules -mindepth 1 -maxdepth 1 -exec rm -rf {} +`
  );

  console.log("cleanup done");
}
EOF
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

echo "Conversion complete!"
