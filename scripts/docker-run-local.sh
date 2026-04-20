#!/usr/bin/env bash
# Build the Dockerfile and run via docker-compose.build.yaml (http://localhost:8080).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec docker compose -f docker-compose.build.yaml up --build "$@"
