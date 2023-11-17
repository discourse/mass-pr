#!/bin/bash
set -euxo pipefail

../scripts/update-rb-linting.sh || true
../scripts/update-js-linting.sh
