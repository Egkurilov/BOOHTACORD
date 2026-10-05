# Issue #109 — social preview local implementation evidence

Date: 2026-10-06. Route: `clients/web/social_preview`. Base: `533af559`.

## Implemented

- Static HTML head contains the Russian description, Open Graph fields, canonical,
  theme color, large-image Twitter fields and image alt text before app JavaScript.
- Production Vite/OCI builds receive `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`.
  Missing or malformed production origin fails the build; development defaults to
  relative metadata URLs and does not embed the production hostname.
- The maintained HTML banner source renders to a public 1200×630 PNG. The generated
  file is 406,799 bytes and contains no guild/member/user data.
- Nginx serves `/social/*.png` as `image/png`, with `nosniff`, a one-day cache for
  successful responses, and 404 for missing files (no SPA HTML fallback).

## Local checks

- PASS: social-preview Vitest — 2 files / 5 tests.
- PASS: OCI web-image argument/config tests — 7 tests.
- PASS: `npm run build` with the production origin; Vue type check and Vite build.
- PASS: built-output verifier checks title/description, required Open Graph/Twitter
  values, absolute URLs, PNG signature/dimensions, and ≤512 KiB size.
- PASS: local unauthenticated preview GET of `/` returns 200 with metadata before
  JavaScript; image GET returns 200 `image/png` (406,799 bytes).
- PASS: local Vite development GET contains only relative social URLs and no
  production hostname.
- PASS: `git diff --check`.

## Not run

- NOT_RUN: public production endpoint/curl and deployed Nginx headers.
- NOT_RUN: Telegram cache refresh, Open Graph/Twitter external parsers and Telegram
  screenshot. These need the implementation deployed and the cache refreshed.
- NOT_RUN: no deploy or production mutation was performed.
