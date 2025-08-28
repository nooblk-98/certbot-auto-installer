#!/usr/bin/env bash

set -euo pipefail

# Backwards-compatible wrapper for the new entrypoint in bin/
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/bin/certbot-auto-installer"

echo "[WARN] certbot-installer.sh is deprecated. Use bin/certbot-auto-installer instead." >&2

exec "$ENTRYPOINT" "$@"

