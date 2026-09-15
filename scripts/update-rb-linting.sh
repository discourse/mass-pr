#!/bin/bash
set -euxo pipefail

cd repo

# Scaffolding, dependency installation, and updates are handled by update-skeleton.sh.

bundle lock --add-platform ruby
bundle lock --remove-platform x86_64-linux &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-18 &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-19 &> /dev/null || true
bundle lock --remove-platform x86_64-darwin-20 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-20 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-21 &> /dev/null || true
bundle lock --remove-platform arm64-darwin-22 &> /dev/null || true

# Remove unnecessary requires
test -d spec && find spec/ -name "*.rb" | xargs -r perl -pi -e 's/require "rails_helper"//'

# Remove unnecessary `js: true` flags in specs
test -d spec && find spec/ -name "*.rb" | xargs -r perl -pi -e 's/, js: true//'

# Format and lint
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")
bundle exec rubocop --color -A || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

# Second stree run to format any rubocop auto-fixes
bundle exec stree write Gemfile $(git ls-files "*.rb") $(git ls-files "*.rake")

# Second rubocop run to ensure stree didn't introduce any violations
bundle exec rubocop --color || (echo "[update-rb-linting] rubocop failed. Correct violations and rerun script." && exit 1)

cd ..
