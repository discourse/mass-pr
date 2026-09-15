#!/bin/bash
set -euxo pipefail

cd repo

# Rename all *.js.es6 to *.js
find . -type d \( -name node_modules -o -name .git \) -prune -o -type f -name "*.js.es6" -exec sh -c 'mv "$1" "${1%.es6}"' _ {} \;

# Scaffolding and dependency installation are handled by update-skeleton.sh.
rm -f package-lock.json

if ! git diff --quiet package.json; then
  # Preserve mass-pr's broader dependency refresh when the manifest changes.
  pnpm update
fi

pnpm dedupe

# Move tests out of test/javascripts
if [[ ! -f "plugin.rb" && -d "test/javascripts" ]]; then
  # Include hidden files and allow retries after a previous run moved the tests.
  (
    shopt -s nullglob dotglob
    files=(test/javascripts/*)
    if (( ${#files[@]} )); then
      mv "${files[@]}" test/
    fi
    rmdir test/javascripts
  )
fi

# Remove the old transpile_js option
if [ -f "plugin.rb" ]; then
  if grep -q 'transpile_js: true' plugin.rb; then
    ruby -e 'File.write("plugin.rb", File.read("plugin.rb").gsub(/^# transpile_js: true\n/, ""))'
  fi
fi

# Fix i18n helper invocations
find . -type f -not -path './node_modules*' -a -name "*.hbs" | xargs -r perl -pi -e 's/\{\{I18n/{{i18n/g'

if [ -f "plugin.rb" ]; then
  pnpm eslint --fix --max-warnings 0 --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm eslint --fix --max-warnings 0 --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  pnpm prettier --write '{assets,admin/assets,test}/**/*.{scss,js,mjs,cjs,gjs,ts,gts,mts,cts,hbs}' --no-error-on-unmatched-pattern
else # Theme
  pnpm prettier --write '{javascripts,desktop,mobile,common,scss,test,stylesheets}/**/*.{scss,js,mjs,cjs,gjs,ts,gts,mts,cts,hbs}' --no-error-on-unmatched-pattern
fi

# Do an extra check after prettier
if [ -f "plugin.rb" ]; then
  pnpm eslint --fix --max-warnings 0 --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  pnpm eslint --fix --max-warnings 0 --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

cd ..
