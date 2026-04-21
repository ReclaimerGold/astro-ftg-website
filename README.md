# Digmar Web Solutions Website

Marketing site for Digmar Web Solutions built with Astro and Tailwind CSS. The site emphasizes:

- Custom websites averaging 80% faster than WordPress
- Managed Nginx hosting with monthly design update tiers ($20 / $50 / $100)
- Edge integration readiness (Cloudflare Workers)
- SEO-first implementation (copy, schema, metadata, analytics/search setup)
- Simplified onboarding and zero-touch management

## Styling

- Tailwind CSS v4 via `@tailwindcss/vite` (see `astro.config.mjs` and `src/styles/global.css`)
- Shared layout utilities: `.layout-container`, `.layout-section`, `.card-surface`, `.btn`, `.btn-primary`, `.btn-secondary`, `.text-eyebrow`

## Tooling (Cursor / agents)

- [AGENTS.md](AGENTS.md) points to project rules and skills.
- Cursor rules live under [`.cursor/rules/`](.cursor/rules/); optional skills under [`.cursor/skills/`](.cursor/skills/).
- Use **Node 22.12+** (see `package.json` `engines` and [`.nvmrc`](.nvmrc)).

## Local development

```sh
npm install
npm run dev
```

Build production output:

```sh
npm run build
```

Preview production build:

```sh
npm run preview
```

## CI (same as GitHub Actions)

```sh
npm run ci
# or
bash scripts/ci.sh
```

GitHub runs:

- [`.github/workflows/ci.yml`](.github/workflows/ci.yml) — on pushes and PRs to `main` / `master`: **Node install + `astro build`**, and a **Docker image build** (no push) to validate the `Dockerfile`.

## Docker and GHCR

- **`Dockerfile`**: multi-stage build (Node 22 → `npm run build` → production `npm ci --omit=dev` → **Node** runs `dist/server/entry.mjs` on port 80 inside the container).
- **`docker-compose.build.yaml`**: build and run locally (default **http://localhost:8080**):

  ```sh
  chmod +x scripts/docker-run-local.sh
  ./scripts/docker-run-local.sh
  ```

- **`docker-compose.yaml`**: **image-only** stack for **Portainer** — set **`DIGMAR_IMAGE`** to the GHCR image (see below). Do not add a `build:` section in Portainer if you only pull from the registry.

Pass Mailgun and optional public env vars into the container at runtime (for example `environment:` or an env file in Portainer) so `POST /api/contact` and `POST /api/support` work in production.

## Full server (Ubuntu LXC / VM)

Production builds use **`output: 'server'`** with **`@astrojs/node`** (standalone). The app listens on a loopback port; **nginx** terminates HTTP/HTTPS and reverse-proxies to Node.

### One-time bootstrap

On a fresh **Ubuntu 24.04** (or similar) system, copy this repository (or download [`scripts/lxc-bootstrap.sh`](scripts/lxc-bootstrap.sh)) and run as **root**:

```sh
chmod +x scripts/lxc-bootstrap.sh
sudo DIGMAR_REPO_URL='https://github.com/your-org/your-repo.git' ./scripts/lxc-bootstrap.sh
```

- **Public HTTPS repo**: set `DIGMAR_SKIP_GIT_AUTH=1` so the script does not prompt for credentials.
- **Private HTTPS (GitHub)**: GitHub does **not** accept account passwords for Git over HTTPS. Use a **Personal Access Token** (classic: `repo`; fine-grained: repository contents read) and either:
  - run interactively and enter username + token when prompted, or
  - set `GIT_USER` and `GIT_TOKEN` (or `GITHUB_TOKEN`) in the environment before running.

The script stores HTTPS credentials for the `web` user via `git credential` (for later `git pull` / [`scripts/lxc-deploy.sh`](scripts/lxc-deploy.sh)). **SSH** URLs (`git@github.com:…`) use your configured deploy keys or agent; no token prompts.

Useful environment variables (all optional except the repo URL when not prompted):

| Variable | Meaning |
|----------|---------|
| `DIGMAR_REPO_URL` | Clone URL (HTTPS or SSH) |
| `DIGMAR_APP_DIR` | Install path (default `/home/web/apps/astro-ftg-website`) |
| `DIGMAR_USER` | Unix user (default `web`) |
| `DIGMAR_SERVICE_PORT` | Node listen port (default `4321`; nginx proxies here) |
| `DIGMAR_SERVER_NAME` | nginx `server_name` (default `_`) |
| `DIGMAR_SKIP_GIT_AUTH` | `1` to skip PAT prompts (public repos) |

Bootstrap installs updates, **Node 22**, **nginx**, creates `systemd` unit **`digmar.service`**, enables it on boot, and copies [`.env.example`](.env.example) to `.env` if missing. Edit `.env` for Mailgun, then:

```sh
sudo systemctl restart digmar
```

### TLS (optional)

```sh
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### Deploy / refresh (updates)

After changing `master` / `main` on the server:

```sh
sudo ./scripts/lxc-deploy.sh
```

Schedule it with **cron** or a **systemd timer** (for example hourly) if you want automatic pulls from the default branch.

### Proxmox notes

- Set the CT **Start at boot** and give stable networking (static IP or DHCP reservation).
- For **HA** between nodes, use Proxmox HA with **shared storage** for the CT disk if you expect failover; understand restart delays and quorum.
- Use **backups** (`vzdump` on a schedule) for quick recovery.
- Optional: HTTP health checks from an external monitor; `Restart=always` on `digmar.service` covers process crashes inside the guest.

### Publish to GitHub Container Registry

1. Create a **GitHub Release** (publish). The workflow [`.github/workflows/release-ghcr.yml`](.github/workflows/release-ghcr.yml) builds and pushes:

   - `ghcr.io/<lowercase-owner>/<lowercase-repo>:<release-tag>` (e.g. `v1.0.0`)
   - `ghcr.io/...:latest` when the release is **not** a prerelease

2. **Packages** permissions: the workflow uses `GITHUB_TOKEN` with `packages: write` (already set in the workflow file).

3. **Portainer**: add registry **ghcr.io** (GitHub username + PAT with `read:packages`). Deploy a stack using `docker-compose.yaml` and env, for example:

   - `DIGMAR_IMAGE=ghcr.io/myorg/my-repo:v1.0.0`
   - `DIGMAR_PORT=8080` (host port mapping)

## Environment variables

Copy `.env.example` to `.env` and fill values.

Required for contact form delivery (Mailgun):

- `MAILGUN_API_KEY`
- `MAILGUN_DOMAIN`
- `MAILGUN_TO_EMAIL`
- `MAILGUN_FROM_EMAIL`

Optional for analytics / verification:

- `PUBLIC_GA_MEASUREMENT_ID`
- `PUBLIC_GSC_VERIFICATION`

## Contact form behavior

- Contact form submits to `POST /api/contact`
- Server-side required field validation
- Basic honeypot field (`company_site`) for bot filtering
- Redirect-based success/error statuses on `/contact`

## Key routes

- `/` - Homepage
- `/hosting` - Hosting plans and stack details
- `/web-design` - Custom web design and SEO service details
- `/process` - Two-week project delivery flow
- `/contact` - Lead capture form
- `/privacy-policy` - Privacy and data handling policy
