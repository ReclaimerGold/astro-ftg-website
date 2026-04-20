---
name: docker-frontend-dev
description: >-
  Prevents permission and ownership problems when running npm or Astro inside Docker
  with the project directory bind-mounted from the host. Use when using docker run -v,
  Dockerfile dev stages, CI containers, or when npm install fails with EACCES on
  node_modules or dist.
---

# Docker + bind-mounted frontend projects

## Problem

`docker run` often runs as **root**. A bind mount (`-v /host/project:/app`) means **`npm ci`** / **`npm install`** create **`node_modules/`** (and often **`dist/`**, **`.astro`**) as **root:root** on the host. The developer’s user then hits **`EACCES: permission denied`** when running npm locally.

## Preferred fix (prevent)

Run the container as the host user:

```bash
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$PWD:/app" -w /app \
  node:22-bookworm \
  bash -lc "npm ci && npm run build"
```

Adjust image/tag to match `package.json` **engines**.

## One-time fix (already polluted)

From the project root on the host:

```bash
sudo chown -R "$(id -un):$(id -gn)" node_modules dist .astro
```

Then prefer `-u "$(id -u):$(id -g)"` for future runs.

## Related project rules

See **`.cursor/rules/docker-bind-mount-node.mdc`**.
