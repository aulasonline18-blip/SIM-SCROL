#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  scripts/create-release-manifest.sh --apk PATH --build-type TYPE --api-url URL --version VERSION [--verify]

Creates manifest/release-manifest.json without building an APK.
If the APK path does not exist, sha256 is null and artifact_status is artifact_missing.
With --verify, a missing APK exits with status 1.
EOF
}

apk_path=""
build_type=""
api_url=""
version=""
verify="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) apk_path="${2:-}"; shift 2 ;;
    --build-type) build_type="${2:-}"; shift 2 ;;
    --api-url) api_url="${2:-}"; shift 2 ;;
    --version) version="${2:-}"; shift 2 ;;
    --verify) verify="true"; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
  esac
done

mkdir -p manifest

if [[ -z "$apk_path" || -z "$build_type" || -z "$api_url" || -z "$version" ]]; then
  show_help
  exit 2
fi

if [[ -f "$apk_path" ]]; then
  sha256="$(sha256sum "$apk_path" | awk '{print $1}')"
  artifact_status="present"
else
  sha256="null"
  artifact_status="artifact_missing"
  if [[ "$verify" == "true" ]]; then
    echo "APK not found: $apk_path" >&2
    exit 1
  fi
fi

app_commit="$(git rev-parse HEAD 2>/dev/null || true)"
app_branch="$(git branch --show-current 2>/dev/null || true)"
app_status="$(git status --short 2>/dev/null | wc -l | tr -d ' ')"
server_path="/root/sim-work/sim-api"
server_commit="$(git -C "$server_path" rev-parse HEAD 2>/dev/null || true)"
server_branch="$(git -C "$server_path" branch --show-current 2>/dev/null || true)"
server_status="$(git -C "$server_path" status --short 2>/dev/null | wc -l | tr -d ' ')"

cat > manifest/release-manifest.json <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_path": "$apk_path",
  "artifact_status": "$artifact_status",
  "sha256": $([[ "$sha256" == "null" ]] && echo null || printf '"%s"' "$sha256"),
  "build_type": "$build_type",
  "api_url": "$api_url",
  "version": "$version",
  "app": {
    "path": "$(pwd)",
    "branch": "$app_branch",
    "commit": "$app_commit",
    "dirty_file_count": $app_status
  },
  "server": {
    "path": "$server_path",
    "branch": "$server_branch",
    "commit": "$server_commit",
    "dirty_file_count": $server_status
  }
}
EOF

echo "Created manifest/release-manifest.json"
