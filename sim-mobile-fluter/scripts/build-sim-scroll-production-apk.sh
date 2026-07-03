#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build apk --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_SERVER_URL=http://167.179.109.137:3000 \
  --dart-define=SIM_ALLOW_HTTP_IN_PRODUCTION=true

