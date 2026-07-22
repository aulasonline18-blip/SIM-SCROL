#!/usr/bin/env bash
set -euo pipefail

manifest_file="manifest/release-manifest.json"
if [[ ! -f "$manifest_file" ]]; then
  echo "No release manifest found at $manifest_file."
  exit 0
fi

apk_path="$(node -e "const m=require('./$manifest_file'); console.log(m.artifact_path || '')")"
expected="$(node -e "const m=require('./$manifest_file'); console.log(m.sha256 || '')")"

if [[ -z "$apk_path" || ! -f "$apk_path" ]]; then
  echo "No APK artifact available to verify."
  exit 0
fi

if [[ -z "$expected" ]]; then
  echo "Manifest has APK path but no SHA256."
  exit 1
fi

actual="$(sha256sum "$apk_path" | awk '{print $1}')"
if [[ "$actual" != "$expected" ]]; then
  echo "SHA256 mismatch for $apk_path" >&2
  exit 1
fi

echo "Provenance verified for $apk_path"
