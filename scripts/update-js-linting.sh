#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

# Rename all *.js.es6 to *.js
find . -depth -name "*.js.es6" -exec sh -c 'mv "$1" "${1%.es6}"' _ {} \;

# Remove the old config files
rm .eslintrc
rm .prettierrc

# Copy these files from skeleton if they do not already exist
if [ -f "repo/plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.template-lintrc.js . || true
else # Theme
  cp -vn ../discourse-theme-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.template-lintrc.js . || true
fi

# Remove the old transpile_js option
if [ -f "repo/plugin.rb" ]; then
  if grep -q 'transpile_js: true' plugin.rb; then
    ruby -e 'File.write("plugin.rb", File.read("plugin.rb").gsub(/^# transpile_js: true\n/, ""))'
  fi
fi

# Use the current linting setup
yarn remove eslint-config-discourse
yarn add --dev @discourse/lint-configs eslint prettier@^2.8.8 ember-template-lint

if [ -f "plugin.rb" ]; then
  yarn prettier --write '{assets,test}/**/*.{scss,js,hbs}' --no-error-on-unmatched-pattern
else # Theme
  yarn prettier --write '{javascripts,desktop,mobile,common,scss,test}/**/*.{scss,js,hbs}' --no-error-on-unmatched-pattern
fi

if [ -f "plugin.rb" ]; then
  yarn eslint --ext .js --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --ext .js --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn ember-template-lint --no-error-on-unmatched-pattern assets/javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
  yarn ember-template-lint --no-error-on-unmatched-pattern admin/assets/javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn ember-template-lint --no-error-on-unmatched-pattern javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
fi

cd ..

../scripts/update-workflows.sh
