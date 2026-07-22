#!/usr/bin/env bash
set -euo pipefail

echo "Requires an emulator or physical device connected."
echo "This script configures execution only; do not report real device smoke without device evidence."
flutter test integration_test
