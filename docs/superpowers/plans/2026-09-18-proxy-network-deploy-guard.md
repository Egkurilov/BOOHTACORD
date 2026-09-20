# Proxy Network Deployment Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure a pinned-image deployment reloads the current Caddyfile and leaves the public proxy attached only to the Voice Platform edge and private Docker networks.

**Architecture:** The release script will start API and web after migrations, then force-recreate proxy so its file bind mount sees the installed Caddyfile. It resolves the proxy container through Compose and fails closed unless its exact runtime network set is `voice-platform_edge` plus `voice-platform_private`; a legacy Fluxer attachment can therefore never silently select an unrelated `api` DNS alias.

**Tech Stack:** Bash, Docker Compose, Caddy, GitHub Actions SSH deployment.

---

### Task 1: Write a hermetic deployment-script regression test

**Files:**
- Create: `scripts/deploy-images.test.sh`
- Test: `scripts/deploy-images.test.sh`

- [x] **Step 1: Create fake Docker and curl executables**

Build a temporary executable `docker` that records command arguments and returns a proxy container ID for `compose … ps -q proxy`, the two allowed network names for `inspect`, and successful output for `pull`, `run`, `up`, `exec`, and `config`. Build a fake `curl` that succeeds. Set `PATH` to use these fakes and set `VOICE_PLATFORM_DIR` to a temporary project with a secure `.env` containing non-`latest` digest image references and `PUBLIC_HOST=v.bootybay.ru`.

- [x] **Step 2: Assert the script initially fails**

Run `bash scripts/deploy-images.sh` and assert the command log is missing an explicit `up … --force-recreate proxy` and does not yet inspect the runtime proxy networks.

- [x] **Step 3: Define the expected command ordering**

After implementation the recorded log must show `pull`, migration `run`, API/web `up`, proxy `up --force-recreate`, proxy network `inspect`, Caddy `validate`, and the HTTPS health curl in that order.

### Task 2: Add closed-world proxy network validation

**Files:**
- Modify: `scripts/deploy-images.sh`
- Modify: `scripts/deploy-images.test.sh`

- [x] **Step 1: Resolve proxy container and its runtime networks**

```bash
proxy_id="$("${compose[@]}" ps -q proxy)"
[[ -n "$proxy_id" ]] || fail "Proxy container is unavailable after deployment."
mapfile -t proxy_networks < <(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$proxy_id" | sort)
expected_proxy_networks=(voice-platform_edge voice-platform_private)
```

- [x] **Step 2: Fail if the exact sorted set differs**

```bash
[[ "${#proxy_networks[@]}" -eq "${#expected_proxy_networks[@]}" ]] || fail "Proxy has an unexpected Docker network attachment."
for index in "${!expected_proxy_networks[@]}"; do
  [[ "${proxy_networks[$index]}" == "${expected_proxy_networks[$index]}" ]] || fail "Proxy has an unexpected Docker network attachment."
done
```

The error must name no users, messages, passwords, or token values.

- [x] **Step 3: Add a negative fake-Docker case**

Return `fluxer_fluxer` in addition to the allowed names and assert the script exits nonzero before Caddy validation or public health checks.

### Task 3: Recreate proxy with the installed Caddyfile and validate it

**Files:**
- Modify: `scripts/deploy-images.sh`
- Modify: `scripts/deploy-images.test.sh`

- [x] **Step 1: Split workload rollout from proxy rollout**

```bash
"${compose[@]}" up -d --no-deps --no-build api web
"${compose[@]}" up -d --no-deps --no-build --force-recreate proxy
```

- [x] **Step 2: Validate the active proxy configuration**

```bash
"${compose[@]}" exec -T proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Run this only after the runtime-network assertion succeeds. Keep the existing HTTPS health check after validation.

- [x] **Step 3: Run the hermetic tests**

Run: `bash scripts/deploy-images.test.sh`

Expected: positive fake deployment passes; the extra Fluxer network fixture fails with the bounded network error.

### Task 4: Validate source and deployed state

**Files:**
- Modify: `evidence/deployment-remote-176108242211-002.json`

- [x] **Step 1: Run source checks**

Run: `bash -n scripts/deploy-images.sh && bash scripts/deploy-images.test.sh && .\scripts\verify-compose-images.ps1 && docker compose --env-file .env.example -f compose.yaml config --quiet`

Expected: all commands pass.

- [x] **Step 2: Install only the release script on the server and execute its network checks without changing images**

Use `sudo install -m 0755` for the script, then exercise a read-only runtime network assertion with the current proxy. Do not use unpinned local image tags through this immutable-image script.

- [x] **Step 3: Record PASS evidence**

Update the existing deployment smoke record only after production confirms proxy health, the exact two runtime networks, public HTTPS health, and public `/metrics` 404.
