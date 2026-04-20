#!/usr/bin/env bash
# Same checks as GitHub Actions CI (Node install + Astro build).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
npm ci
npm run build
echo "ci.sh: OK"
