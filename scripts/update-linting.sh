#!/bin/bash
set -euxo pipefail

../scripts/update-rb-linting.sh
../scripts/update-js-linting.sh
