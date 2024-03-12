#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh

cd repo

# Rename all *.js.es6 to *.js
find . -depth -name "*.js.es6" -exec sh -c 'mv "$1" "${1%.es6}"' _ {} \;

# Remove the old config files
rm -f .eslintrc
rm -f .eslintrc.js
rm -f .prettierrc
rm -f .prettierrc.js
rm -f .template-lintrc.js

rm -f package-lock.json

# Copy these files from skeleton if they do not already exist
if [ -f "plugin.rb" ]; then
  cp -vn ../discourse-plugin-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-plugin-skeleton/.template-lintrc.cjs . || true
else # Theme
  cp -vn ../discourse-theme-skeleton/.eslintrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.prettierrc.cjs . || true
  cp -vn ../discourse-theme-skeleton/.template-lintrc.cjs . || true
fi

yarn install

# Remove the old transpile_js option
if [ -f "plugin.rb" ]; then
  if grep -q 'transpile_js: true' plugin.rb; then
    ruby -e 'File.write("plugin.rb", File.read("plugin.rb").gsub(/^# transpile_js: true\n/, ""))'
  fi
fi

# Fix i18n helper invocations
find . -type f -not -path './node_modules*' -a -name "*.hbs" | xargs sed -i '' 's/{{I18n/{{i18n/g'

# Update all uses of `@class` argument
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.hbs' -o -name '*.gjs' | xargs grep '@class=')" ]; then
  find . -type f -name "*.hbs" -o -name "*.gjs" | xargs sed -i '' 's/@class=/class=/g'
  echo "[update-js-linting] Updated some '@class' args. Please review the changes."
  exit 1
fi

# Update all uses of `inject as service`
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.hbs' -o -name '*.gjs' | xargs grep 'inject as service')" ]; then
  find . -type f -name "*.hbs" -o -name "*.gjs" | xargs sed -i '' 's/inject as service/service/g'
  echo "[update-js-linting] Updated 'inject as service' imports. Please review the changes."
  exit 1
fi

# Find this.transitionToRoute (in lieu of the eslint-ember rule)
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.js' -o -name '*.gjs' | xargs grep -E 'this\.(transitionTo|replaceWith|replaceRoute)')" ]; then
  echo "[update-js-linting] Found uses of deprecated transitionToRoute/transitionTo/replaceWith/replaceRoute. Please review the code."
  exit 1
fi

# Find deprecated lookups, like "site:main"
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.js' | xargs grep ':main\"')" ]; then
  echo "[update-js-linting] Found uses of deprecated '*:main' lookups. Please review the code."
  exit 1
fi

# Find uses of deprecated DSection
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.hbs' -o -name '*.gjs' | xargs grep -E '<DSection|{{#d-section')" ]; then
  echo "[update-js-linting] Found uses of deprecated <DSection />/{{#d-section}}. Please review the code."
  exit 1
fi

# Find querySelector("body")
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.js' -o -name '*.gjs' | xargs grep 'querySelector("body")')" ]; then
  echo "[update-js-linting] Found uses of querySelector(\"body\"). Please review the code and replace it with \`.body\`."
  exit 1
fi

# Find querySelector("html")
if [ -n "$(find . -type f -not -path './node_modules*' -a -name '*.js' -o -name '*.gjs' | xargs grep 'querySelector("html")')" ]; then
  echo "[update-js-linting] Found uses of querySelector(\"html\"). Please review the code and replace it with \`.documentElement\`."
  exit 1
fi

if [ -f "plugin.rb" ]; then
  yarn eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'assets/javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'admin/assets/javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn ember-template-lint --fix --no-error-on-unmatched-pattern 'javascripts/**/*.{gjs,hbs}' || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn prettier --write '{assets,admin/assets,test}/**/*.{scss,js,gjs,hbs}' --no-error-on-unmatched-pattern
else # Theme
  yarn prettier --write '{javascripts,desktop,mobile,common,scss,test}/**/*.{scss,js,gjs,hbs}' --no-error-on-unmatched-pattern
fi

# Do an extra check after prettier
if [ -f "plugin.rb" ]; then
  yarn eslint --fix --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --fix --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

cd ..

../scripts/update-workflows.sh
