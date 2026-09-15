#!/bin/bash
set -euxo pipefail

(cd repo && pnpx @discourse/update-skeleton@latest)

../scripts/update-rb-linting.sh
../scripts/update-js-linting.sh
../scripts/update_css_linting.rb
../scripts/update_types_linting.rb
