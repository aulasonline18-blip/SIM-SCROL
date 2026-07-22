#!/usr/bin/env bash
set -euo pipefail

flutter test --coverage

if command -v genhtml >/dev/null 2>&1; then
  mkdir -p coverage/html
  genhtml coverage/lcov.info --output-directory coverage/html
  echo "Coverage HTML: coverage/html/index.html"
else
  echo "coverage/lcov.info generated. Install lcov/genhtml to generate HTML."
fi
