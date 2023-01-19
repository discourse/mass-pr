#!/bin/bash
set -euxo pipefail

cd repo

if [ ! -f "plugin.rb" ]; then
  echo "Not a plugin"
  exit 1
fi

if ! grep -q 'syntax_tree' Gemfile; then
  sed -i "" "s/gem 'rubocop-discourse'/gem 'rubocop-discourse'; gem 'syntax_tree'; gem 'syntax_tree-disable_ternary';/" Gemfile
  if ! grep -q 'syntax_tree' Gemfile; then
    echo "Unable to automatically install syntax tree. Please fix the Gemfile and restart the script;"
    exit 1
  fi
fi

bundle install
bundle update syntax_tree
bundle update rubocop-discourse

bundle install

sed -i "" "s/default.yml/stree-compat.yml/" .rubocop.yml

if [! -f ".streerc" ]; then
  echo "--print-width=100\n--plugins=plugin/trailing_comma,disable_ternary\n" > ".streerc"
fi

bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

bundle exec rubocop -A . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script.")

# Second stree run to format any rubocop auto-fixes
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

# Second rubocop run to ensure stree didn't introduce any violations
bundle exec rubocop . || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script.")

cd ..

../scripts/update-workflows.sh
