#!/bin/bash
set -euxo pipefail

# Keep existing mass-pr invocations working.
exec ../scripts/update-skeleton.sh
