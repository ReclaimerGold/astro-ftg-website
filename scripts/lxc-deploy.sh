#!/usr/bin/env bash
# Deploy or refresh the app on the server: git pull, npm ci, build, restart digmar, reload nginx.
# Run after bootstrap (typically via cron, systemd timer, or CI SSH).
#
# Run as root: sudo bash scripts/lxc-deploy.sh
#
# Environment (optional):
#   DIGMAR_APP_DIR   App path (default: /home/web/apps/astro-ftg-website)
#   DIGMAR_USER      Unix user (default: web)
set -euo pipefail

DIGMAR_USER="${DIGMAR_USER:-web}"
DIGMAR_APP_DIR="${DIGMAR_APP_DIR:-/home/web/apps/astro-ftg-website}"

require_root() {
	if [[ "${EUID:-0}" -ne 0 ]]; then
		echo "Run as root: sudo $0" >&2
		exit 1
	fi
}

main() {
	require_root
	if [[ ! -d "$DIGMAR_APP_DIR/.git" ]]; then
		echo "No git repo at $DIGMAR_APP_DIR — run scripts/lxc-bootstrap.sh first." >&2
		exit 1
	fi

	# Non-interactive: use stored credentials (from bootstrap) or GIT_ASKPASS / SSH keys.
	export GIT_TERMINAL_PROMPT=0

	sudo -u "$DIGMAR_USER" -H git -C "$DIGMAR_APP_DIR" fetch origin
	sudo -u "$DIGMAR_USER" -H git -C "$DIGMAR_APP_DIR" pull --ff-only

	sudo -u "$DIGMAR_USER" -H bash -lc "cd '$DIGMAR_APP_DIR' && npm ci && npm run build"

	systemctl restart digmar.service
	nginx -t
	systemctl reload nginx
	echo "Deploy complete." >&2
}

main "$@"
