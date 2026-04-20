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

- **`Dockerfile`**: multi-stage build (Node 22 → `npm run build` → nginx serves `dist/`).
- **`docker-compose.build.yaml`**: build and run locally (default **http://localhost:8080**):

  ```sh
  chmod +x scripts/docker-run-local.sh
  ./scripts/docker-run-local.sh
  ```

- **`docker-compose.yaml`**: **image-only** stack for **Portainer** — set **`DIGMAR_IMAGE`** to the GHCR image (see below). Do not add a `build:` section in Portainer if you only pull from the registry.

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
