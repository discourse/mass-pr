#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

if [ ! -f "plugin.rb" ]; then
  echo "Not a plugin, skipping ruby operations"
  exit 0
fi

# Copy these files from skeleton if they do not already exist
cp -vn ../discourse-plugin-skeleton/.streerc . || true
cp -vn ../discourse-plugin-skeleton/.rubocop.yml . || true
cp -vn ../discourse-plugin-skeleton/Gemfile . || true

# Add stree
if ! grep -q 'syntax_tree' Gemfile; then
  sed -i "" "s/gem 'rubocop-discourse'/gem 'rubocop-discourse'; gem 'syntax_tree'/" Gemfile
  if ! grep -q 'syntax_tree' Gemfile; then
    echo "Unable to automatically install syntax tree. Please fix the Gemfile and restart the script;"
    exit 1
  fi
fi

# Remove the old stree plugin
if grep -q 'syntax_tree-disable_ternary' Gemfile; then
  ruby -e 'File.write("Gemfile", File.read("Gemfile").gsub(/^\s*gem .syntax_tree-disable_ternary.\n/, ""))'
  sed -i "" "s:trailing_comma.*:trailing_comma,plugin/disable_auto_ternary:" .streerc
fi

bundle lock --add-platform x86_64-linux
bundle lock --add-platform arm64-darwin-20
bundle update

sed -i "" "s/default.yml/stree-compat.yml/" .rubocop.yml

bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

bundle exec rubocop -A . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

# Second stree run to format any rubocop auto-fixes
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

# Second rubocop run to ensure stree didn't introduce any violations
bundle exec rubocop . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

cd ..

../scripts/update-workflows.sh
