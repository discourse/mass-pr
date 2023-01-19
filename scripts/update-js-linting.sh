#!/bin/bash
set -euxo pipefail

cd repo

yarn upgrade eslint-config-discourse
yarn install

if [ -f "plugin.rb" ]; then
  yarn prettier --write '{assets,test}/**/*.{scss,js,es6,hbs}' --no-error-on-unmatched-pattern
else # Theme
  yarn prettier --write '{javascripts,desktop,mobile,common,scss,test}/**/*.{scss,js,es6,hbs}' --no-error-on-unmatched-pattern
fi

if [ -f "plugin.rb" ]; then
  yarn eslint --ext .js,.js.es6 --no-error-on-unmatched-pattern {test,assets,admin/assets}/javascripts || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn eslint --ext .js,.js.es6 --no-error-on-unmatched-pattern {test,javascripts} || (echo "[update-js-linting] eslint failed, fix violations and re-run script" && exit 1)
fi

if [ -f "plugin.rb" ]; then
  yarn ember-template-lint --no-error-on-unmatched-pattern assets/javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
  yarn ember-template-lint --no-error-on-unmatched-pattern admin/assets/javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
else # Theme
  yarn ember-template-lint --no-error-on-unmatched-pattern javascripts || (echo "[update-js-linting] ember-template-lint failed, fix violations and re-run script" && exit 1)
fi

cd ..

../scripts/update-workflows.sh
