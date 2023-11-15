#!/bin/bash
set -euxo pipefail

if [ ! -d ".github" ]; then
  git clone https://github.com/discourse/.github .github
fi

mkdir -p repo/.github/workflows
if [ -f "repo/plugin.rb" ]; then
  cp .github/plugin-workflow-templates/discourse-plugin.yml repo/.github/workflows
else
  cp .github/theme-workflow-templates/discourse-theme.yml repo/.github/workflows
fi

# Cleanup old workflows
git -C repo rm --ignore-unmatch .github/workflows/plugin-linting.yml .github/workflows/plugin-tests.yml .github/workflows/component-linting.yml .github/workflows/component-tests.yml
