#!/usr/bin/env bash
# Bootstrap Ubuntu 24.04+ LXC/VM: system packages, Node 22, clone repo, nginx reverse proxy,
# systemd service for the Astro Node standalone server.
#
# Run as root: sudo bash scripts/lxc-bootstrap.sh
#
# Environment (optional):
#   DIGMAR_REPO_URL       Git remote (HTTPS or SSH). Prompted if unset.
#   DIGMAR_APP_DIR        App path (default: /home/web/apps/astro-ftg-website)
#   DIGMAR_USER           Unix user (default: web)
#   DIGMAR_SERVICE_PORT   Port for Node (default: 4321; nginx proxies here)
#   DIGMAR_SERVER_NAME    nginx server_name (default: _)
#   GIT_USER              GitHub username for HTTPS + token auth
#   GIT_TOKEN / GITHUB_TOKEN   PAT (skips interactive prompts if set)
#   DIGMAR_SKIP_GIT_AUTH  If 1, skip PAT prompts (public HTTPS or SSH with keys)
#
# GitHub HTTPS: account passwords are not accepted; use a Personal Access Token (classic: repo;
# fine-grained: repository contents read) as the token.
set -euo pipefail

DIGMAR_USER="${DIGMAR_USER:-web}"
DIGMAR_APP_DIR="${DIGMAR_APP_DIR:-/home/web/apps/astro-ftg-website}"
DIGMAR_SERVICE_PORT="${DIGMAR_SERVICE_PORT:-4321}"
DIGMAR_SERVER_NAME="${DIGMAR_SERVER_NAME:-_}"

require_root() {
	if [[ "${EUID:-0}" -ne 0 ]]; then
		echo "Run as root: sudo $0" >&2
		exit 1
	fi
}

apt_install_base() {
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y
	apt-get -y full-upgrade
	apt-get install -y --no-install-recommends curl ca-certificates gnupg git nginx
}

install_node_22() {
	if command -v node >/dev/null 2>&1; then
		local v
		v="$(node -p "process.versions.node" 2>/dev/null || echo 0)"
		if [[ "$(printf '%s\n' "22.12.0" "$v" | sort -V | head -1)" == "22.12.0" ]]; then
			return 0
		fi
	fi
	curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
	apt-get install -y nodejs
}

ensure_user() {
	if ! id -u "$DIGMAR_USER" &>/dev/null; then
		useradd -m -s /bin/bash "$DIGMAR_USER"
	fi
}

prompt_repo_url() {
	if [[ -z "${DIGMAR_REPO_URL:-}" ]]; then
		read -r -p "Git repository URL (HTTPS or SSH): " DIGMAR_REPO_URL
	fi
	if [[ -z "${DIGMAR_REPO_URL:-}" ]]; then
		echo "DIGMAR_REPO_URL is required." >&2
		exit 1
	fi
}

collect_github_https_credentials() {
	local url="$1"
	[[ "$url" =~ ^https://([^@]+@)?github\.com ]] || return 0
	if [[ "${DIGMAR_SKIP_GIT_AUTH:-0}" == "1" ]]; then
		return 0
	fi
	GIT_TOKEN="${GIT_TOKEN:-${GITHUB_TOKEN:-}}"
	if [[ -n "$GIT_TOKEN" ]]; then
		if [[ -z "${GIT_USER:-}" ]]; then
			read -r -p "GitHub username (for stored HTTPS credentials): " GIT_USER
		fi
		return 0
	fi
	echo "GitHub does not accept account passwords for HTTPS Git. Use a Personal Access Token (PAT) with access to this repository." >&2
	read -r -p "GitHub username: " GIT_USER
	read -r -s -p "GitHub token (PAT): " GIT_TOKEN
	echo >&2
	if [[ -z "${GIT_USER:-}" || -z "${GIT_TOKEN:-}" ]]; then
		echo "GIT_USER and GIT_TOKEN are required for private HTTPS clones." >&2
		exit 1
	fi
}

store_git_credentials() {
	local user="$1" token="$2"
	if [[ -z "$user" || -z "$token" ]]; then
		return 0
	fi
	sudo -u "$DIGMAR_USER" -H git config --global credential.helper store
	printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n' "$user" "$token" |
		sudo -u "$DIGMAR_USER" -H git credential approve
}

clone_or_update_repo() {
	local parent
	parent="$(dirname "$DIGMAR_APP_DIR")"
	mkdir -p "$parent"
	chown "$DIGMAR_USER:$DIGMAR_USER" "$parent"

	if [[ -d "$DIGMAR_APP_DIR/.git" ]]; then
		echo "Repository exists at $DIGMAR_APP_DIR; fetching..."
		sudo -u "$DIGMAR_USER" -H git -C "$DIGMAR_APP_DIR" fetch origin
		sudo -u "$DIGMAR_USER" -H git -C "$DIGMAR_APP_DIR" pull --ff-only
		return 0
	fi

	if [[ "$DIGMAR_REPO_URL" =~ ^git@ ]]; then
		sudo -u "$DIGMAR_USER" -H git clone "$DIGMAR_REPO_URL" "$DIGMAR_APP_DIR"
		return 0
	fi

	if [[ "$DIGMAR_REPO_URL" =~ ^https://([^@]+@)?github\.com ]] && [[ -n "${GIT_TOKEN:-}" ]]; then
		store_git_credentials "$GIT_USER" "$GIT_TOKEN"
	fi

	sudo -u "$DIGMAR_USER" -H git clone "$DIGMAR_REPO_URL" "$DIGMAR_APP_DIR"
}

ensure_env_file() {
	local env_file="$DIGMAR_APP_DIR/.env"
	if [[ ! -f "$env_file" ]] && [[ -f "$DIGMAR_APP_DIR/.env.example" ]]; then
		sudo -u "$DIGMAR_USER" -H cp "$DIGMAR_APP_DIR/.env.example" "$env_file"
		chmod 600 "$env_file"
		echo "Created $env_file from .env.example — edit Mailgun and optional public env vars before going live." >&2
	fi
}

build_app() {
	sudo -u "$DIGMAR_USER" -H bash -lc "cd '$DIGMAR_APP_DIR' && npm ci && npm run build"
}

write_systemd_unit() {
	cat >/etc/systemd/system/digmar.service <<EOF
[Unit]
Description=Digmar Astro server (Node standalone)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$DIGMAR_USER
Group=$DIGMAR_USER
WorkingDirectory=$DIGMAR_APP_DIR
Environment=HOST=127.0.0.1
Environment=PORT=$DIGMAR_SERVICE_PORT
EnvironmentFile=-$DIGMAR_APP_DIR/.env
ExecStart=/usr/bin/node $DIGMAR_APP_DIR/dist/server/entry.mjs
Restart=always
RestartSec=3
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
}

write_nginx_site() {
	cat >/etc/nginx/sites-available/digmar <<EOF
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name $DIGMAR_SERVER_NAME;

	location / {
		proxy_pass http://127.0.0.1:$DIGMAR_SERVICE_PORT;
		proxy_http_version 1.1;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto \$scheme;
	}
}
EOF
	rm -f /etc/nginx/sites-enabled/default
	ln -sf /etc/nginx/sites-available/digmar /etc/nginx/sites-enabled/digmar
}

enable_services() {
	systemctl daemon-reload
	systemctl enable --now digmar.service
	nginx -t
	systemctl enable --now nginx
	systemctl reload nginx
}

main() {
	require_root
	prompt_repo_url
	collect_github_https_credentials "$DIGMAR_REPO_URL"
	apt_install_base
	install_node_22
	ensure_user
	clone_or_update_repo
	chown -R "$DIGMAR_USER:$DIGMAR_USER" "$DIGMAR_APP_DIR"
	ensure_env_file
	build_app
	write_systemd_unit
	write_nginx_site
	enable_services
	echo "Bootstrap complete. Site (via nginx): http://$(hostname -I | awk '{print $1}')/" >&2
	echo "Edit $DIGMAR_APP_DIR/.env for Mailgun, then: sudo systemctl restart digmar" >&2
}

main "$@"
