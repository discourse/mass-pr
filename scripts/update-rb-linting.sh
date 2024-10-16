#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

# Copy these files from skeleton if they do not already exist
if [ -f "plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/.streerc . || true
  cp -vn ../discourse-plugin-skeleton/.rubocop.yml . || true
  cp -vn ../discourse-plugin-skeleton/Gemfile . || true
else # Theme
  cp -vn ../discourse-theme-skeleton/.streerc . || true
  cp -vn ../discourse-theme-skeleton/.rubocop.yml . || true
  cp -vn ../discourse-theme-skeleton/Gemfile . || true
fi

# Add stree
if ! grep -q 'syntax_tree' Gemfile; then
  sed -i "" "s/gem .rubocop-discourse./gem 'rubocop-discourse'; gem 'syntax_tree'/" Gemfile
  if ! grep -q 'syntax_tree' Gemfile; then
    echo "Unable to automatically install syntax tree. Please fix the Gemfile and restart the script;"
    exit 1
  fi
fi

# Remove the old stree plugin
if grep -q 'syntax_tree-disable_ternary' Gemfile; then
  ruby -e 'File.write("Gemfile", File.read("Gemfile").gsub(/^\s*gem .syntax_tree-disable_ternary.\n/, ""))'
fi
if grep -q ',disable_ternary' .streerc; then
  sed -i "" "s:trailing_comma.*:trailing_comma,plugin/disable_auto_ternary:" .streerc
fi

sed -i "" "s/default.yml/stree-compat.yml/" .rubocop.yml

bundle update
bundle update --bundler

bundle lock --add-platform ruby
bundle lock --remove-platform x86_64-linux &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-18 &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-19 &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-20 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-20 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-21 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-22 &> /dev/null || true

# Remove unnecessary requires
test -d /spec && find spec/ -name "*.rb" | xargs sed -i '' 's/require "rails_helper"//'

# Format and lint
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")
bundle exec rubocop -A . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

# Second stree run to format any rubocop auto-fixes
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

# Second rubocop run to ensure stree didn't introduce any violations
bundle exec rubocop . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

cd ..

../scripts/update-workflows.sh
