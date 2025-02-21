#!/bin/bash
set -euxo pipefail

../scripts/add-mit-license.sh
../scripts/update-rb-linting.sh
../scripts/update-js-linting.sh
