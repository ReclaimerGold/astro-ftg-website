---
name: astro-static-forms
description: >-
  Guides Astro static-site projects on contact forms, POST API routes, Mailgun, and
  deployment options when server endpoints are not available on pure static hosts.
  Use when editing src/pages/api/, contact forms, form actions, or when the user asks
  about form delivery, SSR, or static vs server rendering for Astro.
---

# Astro static output and forms

## Context

This repo uses **`output: 'server'`** with **`@astrojs/node`** so **`POST`** handlers under `src/pages/api/` run in production. **Pure static file hosts** (upload-only `dist/`) cannot execute those routes; use this Node deployment, Docker, or an adapter/host that runs the server.

## Checklist when changing forms

1. **Confirm target host**: Netlify/Vercel/Cloudflare Pages support **serverless** or **SSR** with the right adapter; “upload `dist/` only” hosts do not run `POST /api/contact`.
2. **Keep server validation**: required fields, email shape, honeypot; do not rely on client-only checks.
3. **Secrets**: `MAILGUN_*` and similar belong in **host env**, never committed.
4. **Build**: `GET` on API routes may be probed during static generation; a **405 GET** response avoids confusing warnings (see `.cursor/rules/astro-static-api-routes.mdc`).

## Options if static hosting cannot run POST

- Add **`@astrojs/netlify`** / **`@astrojs/vercel`** (or appropriate adapter) and switch to **SSR/hybrid** for the API route, **or**
- **Formspree**, **Getform**, **Web3Forms**, or **Mailgun HTTP API** from a **serverless function** outside Astro, **or**
- Point the form `action` to an external endpoint.

## Verification

- `npm run build` with **Node >= 22.12** (see `package.json` `engines`).
