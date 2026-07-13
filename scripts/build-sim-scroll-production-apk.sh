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

# APK externo de teste/banca: a API atual ainda roda em HTTP neste host.
# O arquivo-fonte volta ao estado Google Play-safe ao final da build.
cat > "$network_config" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">167.179.109.137</domain>
    </domain-config>
</network-security-config>
XML

flutter build apk --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_SERVER_URL=http://167.179.109.137:3000 \
  --dart-define=SIM_ALLOW_HTTP_IN_PRODUCTION=true \
  -PSIM_ANDROID_APPLICATION_ID=com.example.sim_mobile
