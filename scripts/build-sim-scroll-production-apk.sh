#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

network_config="android/app/src/main/res/xml/network_security_config.xml"
network_config_backup="$(mktemp)"
cp "$network_config" "$network_config_backup"
cleanup() {
  cp "$network_config_backup" "$network_config"
  rm -f "$network_config_backup"
}
trap cleanup EXIT

server_url="${SIM_SERVER_URL:?SIM_SERVER_URL must be set to the public HTTPS production API URL}"
if [[ "$server_url" != https://* ]]; then
  echo "SIM_SERVER_URL must use HTTPS for a Google Play production build." >&2
  exit 1
fi

cat > "$network_config" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
XML

flutter build appbundle --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_BILLING_PROVIDER=google_play \
  --dart-define=SIM_SERVER_URL="$server_url" \
  -PSIM_ANDROID_APPLICATION_ID=com.aulasonline.sim \
  -PSIM_REQUIRE_RELEASE_SIGNING=true
