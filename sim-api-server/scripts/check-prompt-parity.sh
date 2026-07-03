#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_PROMPTS_DIR="${SIM_WEB_PROMPTS_DIR:-}"

required=(
  "prompts/t00.txt"
  "prompts/t02.txt"
  "prompts/adendo_doubt.txt"
  "prompts/adendo_recovery.txt"
  "prompts/adendo_revision.txt"
  "prompts/adendo_amparo_t00.txt"
  "prompts/adendo_amparo_t02.txt"
)

for file in "${required[@]}"; do
  test -s "$ROOT/$file"
done

if [[ -z "$WEB_PROMPTS_DIR" ]]; then
  echo "Prompt files present. Set SIM_WEB_PROMPTS_DIR to compare against the canonical Web prompt folder."
  md5sum "${required[@]/#/$ROOT/}"
  exit 0
fi

declare -A map=(
  ["prompts/t00.txt"]="T00_MULTIMODAL_bootstrap.txt"
  ["prompts/t02.txt"]="T02 — UNIVERSAL PEDAGOGICAL PARTITURE.txt"
  ["prompts/adendo_doubt.txt"]="DOUBT ADDENDUM.txt"
  ["prompts/adendo_recovery.txt"]="recovery_addendum.txt"
  ["prompts/adendo_revision.txt"]="review_addendum.txt"
  ["prompts/adendo_amparo_t00.txt"]="ADDENDUM T00 — SUPPORT.txt"
  ["prompts/adendo_amparo_t02.txt"]="ADDENDUM T02 — SUPPORT.txt"
)

for local_file in "${!map[@]}"; do
  canonical="$WEB_PROMPTS_DIR/${map[$local_file]}"
  test -s "$canonical"
  diff -u <(sed '1s/^\xEF\xBB\xBF//' "$ROOT/$local_file" | sed 's/[[:space:]]*$//') \
          <(sed '1s/^\xEF\xBB\xBF//' "$canonical" | sed 's/[[:space:]]*$//')
done

echo "Prompt parity OK."
