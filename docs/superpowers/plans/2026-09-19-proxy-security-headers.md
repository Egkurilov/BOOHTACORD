# Proxy Security Headers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add conservative response headers at the public reverse proxy without affecting microphone, screen capture, WebRTC signalling, or media transport.

**Architecture:** The Caddy site block adds fixed headers for content sniffing, embedding, referrer disclosure, and browser permissions unused by this product. A static verifier requires the exact header values and preserves the existing private `/metrics` denial and RTC forwarding boundary.

**Tech Stack:** Caddyfile, PowerShell static verification.

---

### Task 1: Specify proxy header invariants

**Files:**
- Create: `scripts/verify-proxy-security-headers.ps1`
- Test: `scripts/verify-proxy-security-headers.ps1`

- [x] **Step 1: Require each fixed header and existing critical route boundary.**

```powershell
foreach ($line in @(
    'X-Content-Type-Options "nosniff"',
    'X-Frame-Options "SAMEORIGIN"',
    'Referrer-Policy "no-referrer"',
    'Permissions-Policy "camera=(), geolocation=(), payment=(), usb=()"'
)) {
    if ($caddyfile -notmatch [regex]::Escape($line)) { throw "Missing proxy header: $line" }
}
```

- [x] **Step 2: Run the verifier before the Caddyfile change.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-proxy-security-headers.ps1`

Expected: failure identifying the first absent header.

### Task 2: Add headers and validate without proxy recreation

**Files:**
- Modify: `docker/Caddyfile:1-23`
- Test: `scripts/verify-proxy-security-headers.ps1`

- [x] **Step 1: Place the header block inside the site route before API, RTC, and web handling.**

```caddyfile
header {
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
    Referrer-Policy "no-referrer"
    Permissions-Policy "camera=(), geolocation=(), payment=(), usb=()"
}
```

- [x] **Step 2: Run the static verifier and existing deployment script test.**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify-proxy-security-headers.ps1` and `bash scripts/deploy-images.test.sh`.

Expected: both commands pass.

- [x] **Step 3: Do not recreate the proxy during the active media session.**

Deploy after the session ends, validate the Caddyfile in the container, then inspect HTTPS response headers and `/metrics` returning `404`.
