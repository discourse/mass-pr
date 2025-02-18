#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

# Copy the config from skeleton if it does not already exist
cp -vn ../discourse-plugin-skeleton/stylelint.config.mjs . || true

if [ -f "plugin.rb" ]; then
  pnpm stylelint --fix --allow-empty-input "assets/**/*.scss" || (echo "[update-css-linting] stylelint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm stylelint --fix --allow-empty-input "{javascripts,desktop,mobile,common,scss}/**/*.scss" || (echo "[update-css-linting] stylelint failed, fix violations and re-run script" && exit 1)
fi

cd ..

../scripts/update-workflows.sh
