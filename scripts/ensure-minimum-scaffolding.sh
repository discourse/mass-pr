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
    "@discourse/lint-configs": "2.43.0",
    "@glint/ember-tsc": "1.1.1",
    "concurrently": "^9.2.1",
    "discourse": "npm:@discourse/types@2026.3.0-887c5be4",
    "ember-template-lint": "7.9.3",
    "eslint": "9.39.2",
    "prettier": "3.8.1",
    "stylelint": "17.4.0"
  } |
  # Sort deps alphabetically
  .devDependencies = (.devDependencies | to_entries | sort_by(.key) | from_entries) |
  del(.devDependencies["@babel/plugin-proposal-decorators"]) |

  .scripts = (.scripts // {}) |

  .engines = (.engines // {}) |
  .engines *= {
    "node": ">= 22",
    "npm": "please-use-pnpm",
    "yarn": "please-use-pnpm",
    "pnpm": "^10"
  } |
  .packageManager = "pnpm@10.28.0" |

  # Have these fields first
  { private, devDependencies, scripts } + del(.private // .devDependencies // .scripts)
' repo/package.json > repo/temp.json
mv repo/temp.json repo/package.json

if [ -f "repo/plugin.rb" ]; then
  jq '.scripts *= {
    "lint": "concurrently \"pnpm:lint:*(!fix)\" --names \"lint:\"",
    "lint:fix": "concurrently \"pnpm:lint:*:fix\" --names \"fix:\"",
    "lint:css": "pnpm stylelint assets/stylesheets/**/*.scss --allow-empty-input",
    "lint:css:fix": "pnpm stylelint assets/stylesheets/**/*.scss --fix --allow-empty-input",
    "lint:js": "eslint {assets,admin/assets,test}/javascripts --cache --no-error-on-unmatched-pattern",
    "lint:js:fix": "eslint {assets,admin/assets,test}/javascripts --fix --no-error-on-unmatched-pattern",
    "lint:hbs": "ember-template-lint {assets,admin/assets,test}/javascripts/**/*.gjs --no-error-on-unmatched-pattern",
    "lint:hbs:fix": "ember-template-lint {assets,admin/assets,test}/javascripts/**/*.gjs --fix --no-error-on-unmatched-pattern",
    "lint:prettier": "pnpm prettier assets/stylesheets/**/*.scss {assets,admin/assets,test}/javascripts/**/*.{js,gjs} --check --no-error-on-unmatched-pattern",
    "lint:prettier:fix": "pnpm prettier assets/stylesheets/**/*.scss {assets,admin/assets,test}/javascripts/**/*.{js,gjs} -w --no-error-on-unmatched-pattern",
    "lint:types": "ember-tsc -b"
  }' repo/package.json > repo/temp.json
  mv repo/temp.json repo/package.json
else # Theme
  jq '.scripts *= {
    "lint": "concurrently \"pnpm:lint:*(!fix)\" --names \"lint:\"",
    "lint:fix": "concurrently \"pnpm:lint:*:fix\" --names \"fix:\"",
    "lint:css": "pnpm stylelint {javascripts,desktop,mobile,common,scss}/**/*.scss --allow-empty-input",
    "lint:css:fix": "pnpm stylelint {javascripts,desktop,mobile,common,scss}/**/*.scss --fix --allow-empty-input",
    "lint:js": "eslint {javascripts,test} --cache --no-error-on-unmatched-pattern",
    "lint:js:fix": "eslint {javascripts,test} --fix --no-error-on-unmatched-pattern",
    "lint:hbs": "ember-template-lint javascripts/**/*.gjs --no-error-on-unmatched-pattern",
    "lint:hbs:fix": "ember-template-lint javascripts/**/*.gjs --fix --no-error-on-unmatched-pattern",
    "lint:prettier": "pnpm prettier {javascripts,desktop,mobile,common,scss}/**/*.scss {javascripts,test}/**/*.{js,gjs} --check --no-error-on-unmatched-pattern",
    "lint:prettier:fix": "pnpm prettier {javascripts,desktop,mobile,common,scss}/**/*.scss {javascripts,test}/**/*.{js,gjs} -w --no-error-on-unmatched-pattern",
    "lint:types": "ember-tsc -b"
  }' repo/package.json > repo/temp.json
  mv repo/temp.json repo/package.json
fi

# Copy these files from skeleton if they do not already exist
if [ -f "repo/plugin.rb" ]; then
  cp -vn discourse-plugin-skeleton/.gitignore repo || true
else # Theme
  cp -vn discourse-theme-skeleton/.gitignore repo || true
fi

if ! grep -q 'node_modules' repo/.gitignore; then
  # ensure newline
  [ -n "$(tail -c1 repo/.gitignore)" ] && echo >> repo/.gitignore

  # add the entry
  echo "node_modules" >> repo/.gitignore
fi

if ! grep -q '^\.eslintcache' repo/.gitignore; then
  # fixup incorrectly added entries
  sed 's/\.eslintcache//' repo/.gitignore > repo/.gitignore.tmp
  mv repo/.gitignore.tmp repo/.gitignore

  # ensure newline
  [ -n "$(tail -c1 repo/.gitignore)" ] && echo >> repo/.gitignore

  # add the entry
  echo ".eslintcache" >> repo/.gitignore
fi
