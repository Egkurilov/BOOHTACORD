# Issue #109 Social Preview Implementation Plan

> **For agentic workers:** Run inline in this task, one step at a time. Preserve the current application mount and authentication behavior.

**Goal:** Give the public BOOHTACORD landing document a complete Russian social card with an origin-correct public 1200×630 PNG, without embedding production URLs in development builds.

**Architecture:** Keep the social strings and canonical paths in the static HTML head so crawlers can read them before JavaScript. A small pure resolver supplies the origin to Vite's HTML transform; the existing Docker and CI build edges pass the explicit public variable. A maintained standalone HTML source renders the public PNG; Nginx serves it anonymously with image MIME and a bounded cache policy.

**Tech Stack:** Vue/Vite HTML transform, TypeScript/Vitest, Node/Playwright asset renderer, Python unittest, Nginx, Docker build args.

---

## Operating brief

- Route: `small_direct`, one public social-preview capability.
- Preservation baseline: keep `<title>BOOHTACORD</title>`, `/favicon.png`, `#app`, and `/src/main.ts`; no Vue auth/runtime changes.
- Source-of-truth requirements: issue #109; exactly the proposed Russian title and description; public, guild-neutral content only.
- Files: `clients/web/index.html`; `clients/web/src/social_preview/{origin.ts,origin.spec.ts,metadata.spec.ts}`; `clients/web/social-preview/boohtacord-og.html`; `clients/web/scripts/{render_social_preview.mjs,verify_social_preview.mjs}`; `clients/web/vite.config.ts`, `Dockerfile`, `nginx.conf`, `package.json`; `clients/web/tests` not needed; `.github/workflows/ci-frontend.yaml`; `deploy/compose.dev.yaml`; `tools/build/server/{images.py,test_social_preview.py}`; `tools/ci/native/web.py`; this plan.
- Native checks: focused Vitest, focused Python unittest, Vite production build plus built-output verification, local unauthenticated HTTP checks for `index.html` and PNG, `git diff --check`.
- Acceptance boundary: Telegram cache refresh/screenshot and deployed CDN response remain NOT_RUN until deployment and account/device access.
- Stop: all local build outputs carry production origin only when explicitly supplied, development has no production URL, metadata and PNG verify, ordinary app entry remains intact.

## Task 1: Pin the HTML contract and origin behavior

1. Create `src/social_preview/origin.spec.ts` for these contracts:
   - `resolvePublicOrigin('https://V.BOOTYBAY.RU/', 'production')` returns `https://v.bootybay.ru`.
   - absent production origin throws; HTTP, credentials, path, query, or fragment are rejected for production.
   - absent non-production origin returns empty string; supplied valid local origin is normalized.
2. Create `src/social_preview/metadata.spec.ts` that reads `../../index.html`, asserts every required description, Open Graph, Twitter, canonical, theme-color and image-dimension tag is in `<head>` before the app script, has nonempty content, uses `__SOCIAL_ORIGIN__` for URLs, and preserves title/favicon/app mount.
3. Run from `clients/web`: `npm test -- src/social_preview`; expected RED because the resolver and metadata do not exist.

## Task 2: Implement static metadata and build-origin wiring

1. Add `src/social_preview/origin.ts` with a pure origin validator; production requires an HTTPS origin with no credentials, path, search or fragment. Non-production with no configured value returns `''`.
2. Use Vite `loadEnv(mode, process.cwd(), 'VITE_')`; a `transformIndexHtml` hook replaces all `__SOCIAL_ORIGIN__` tokens with the validated result.
3. Add the requested description, Open Graph fields, canonical link, theme-color and large-image Twitter fields to the static `<head>`. Use the issue's exact title and description, absolute production image URL, 1200×630 dimensions, `image/png`, and descriptive image alt text.
4. Add `ARG`/`ENV VITE_PUBLIC_ORIGIN` to the web Dockerfile; pass it through `tools/build/server/images.py`; require the public origin in production CI/frontend and immutable OCI build jobs. Give only `deploy/compose.dev.yaml` a localhost build-arg default.
5. Extend focused Python tests for the OCI build argument and invalid/missing origin. Update `tools/ci/native/web.py` to execute built-social-preview verification after Vite build.
6. Run the focused Vitest and Python tests; expected PASS.

## Task 3: Render and verify the public banner

1. Add a standalone `social-preview/boohtacord-og.html` canvas design with the existing BOOHTACORD brand mark, requested headline, invitation copy, dark high-contrast treatment and at least 64px safe margins. Do not include a guild name, member, avatar, message or other private data.
2. Add `scripts/render_social_preview.mjs` using installed Playwright Chromium. Open the source at a 1200×630 viewport, await fonts and logo decode, and write `public/social/boohtacord-og-1200x630.png`.
3. Add `scripts/verify_social_preview.mjs` to inspect built `dist/index.html` for complete nonempty tags and expected absolute production URLs; validate PNG signature, 1200×630 IHDR and size ≤512 KiB.
4. Add an Nginx `/social/` static location with `try_files $uri =404`, `image/png` MIME through standard Nginx types, `nosniff`, and `Cache-Control: public, max-age=86400`; missing social assets must never fall back to application HTML.
5. Render the checked-in PNG, run the Vite production build with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`, run built-output verification and local no-cookie HTTP checks, then inspect `git diff --check` and all changed-file line counts.

## Review

- Compare the transformed production head against the exact metadata contract in issue #109.
- Confirm dev transformation with no variable has only relative URLs and no production hostname.
- Confirm `index.html`, favicon and Vue mount are preserved and no private guild/member data appears in metadata/banner.
- Leave issue #109 open; production HTTP/Telegram cache/device evidence is not available from a local implementation.
