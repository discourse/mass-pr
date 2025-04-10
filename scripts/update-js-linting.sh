#!/bin/bash
set -euxo pipefail

cd repo

# Rename all *.js.es6 to *.js
find . -depth -name "*.js.es6" -exec sh -c 'mv "$1" "${1%.es6}"' _ {} \;

# Remove the old config files
rm -f .eslintrc
rm -f .eslintrc.js
rm -f .prettierrc
rm -f .prettierrc.js
rm -f .template-lintrc.js
rm -f .eslintrc.cjs

rm -f package-lock.json

# Copy these files from skeleton if they do not already exist
if [ -f "plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/eslint.config.mjs . || true
  cp -vn ../discourse-plugin-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.template-lintrc.cjs . || true
else # Theme
  cp -vn ../discourse-theme-skeleton/eslint.config.mjs . || true
  cp -vn ../discourse-theme-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.template-lintrc.cjs . || true
fi

if git diff --quiet package.json; then
  pnpm install
else
  # If package.json has changed, update all dependencies
  pnpm update
fi

pnpm dedupe

# Move tests out of test/javascripts
if [[ ! -f "plugin.rb" && -d "test/javascripts" ]]; then
  mv test/javascripts/* test/
fi

# Remove the old transpile_js option
if [ -f "plugin.rb" ]; then
  if grep -q 'transpile_js: true' plugin.rb; then
    ruby -e 'File.write("plugin.rb", File.read("plugin.rb").gsub(/^# transpile_js: true\n/, ""))'
  fi
fi

# Fix i18n helper invocations
find . -type f -not -path './node_modules*' -a -name "*.hbs" | xargs sed -i '' 's/{{I18n/{{i18n/g'

if [ -f "plugin.rb" ]; then
  pnpm eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  pnpm ember-template-lint --fix --no-error-on-unmatched-pattern 'assets/javascripts' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
  pnpm ember-template-lint --fix --no-error-on-unmatched-pattern 'admin/assets/javascripts' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm ember-template-lint --fix --no-error-on-unmatched-pattern 'javascripts' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  pnpm prettier --write '{assets,admin/assets,test}/**/*.{scss,js,mjs,cjs,gjs,hbs}' --no-error-on-unmatched-pattern
else # Theme
  pnpm prettier --write '{javascripts,desktop,mobile,common,scss,test}/**/*.{scss,js,mjs,cjs,gjs,hbs}' --no-error-on-unmatched-pattern
fi

# Do an extra check after prettier
if [ -f "plugin.rb" ]; then
  pnpm eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

cd ..
