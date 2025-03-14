#!/bin/bash
set -euxo pipefail

../scripts/ensure-minimum-scaffolding.sh
../scripts/update-workflows.sh

../scripts/update-rb-linting.sh
../scripts/update-js-linting.sh
../scripts/update_css_linting.rb
