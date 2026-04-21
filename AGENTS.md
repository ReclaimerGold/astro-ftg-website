# Agent notes (Digmar / Astro site)

- **Cursor rules**: See [`.cursor/rules/`](.cursor/rules/) for enforced conventions (Astro frontmatter objects, Docker bind mounts, static API routes, Node engines, Tailwind UI tokens).
- **Cursor skills**: See [`.cursor/skills/`](.cursor/skills/) for workflow guidance (`astro-static-forms`, `docker-frontend-dev`).
- **Node**: Use **Node >= 22.12** locally or in CI to match `package.json` `engines` and Astro 6.
- **Docker / GHCR**: [`Dockerfile`](Dockerfile) runs the Astro **Node standalone** server (`dist/server/entry.mjs`) on port 80. [`docker-compose.yaml`](docker-compose.yaml) is image-only for Portainer; [`docker-compose.build.yaml`](docker-compose.build.yaml) builds locally. Releases publish to GHCR via [`.github/workflows/release-ghcr.yml`](.github/workflows/release-ghcr.yml).
