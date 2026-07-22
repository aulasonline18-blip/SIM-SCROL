#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Running deterministic SLA efficiency contracts..."
flutter test test/sla_efficiency_contract_test.dart
