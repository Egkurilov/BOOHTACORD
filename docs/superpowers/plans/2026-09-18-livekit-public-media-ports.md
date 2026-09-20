# LiveKit Public Media Ports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the minimum LiveKit TCP fallback and UDP media range required for an external browser to exchange media with this self-hosted deployment.

**Architecture:** Caddy continues proxying HTTP/WebSocket signalling through port 8088. LiveKit retains its un-published signalling port 7880 and joins `private` for Caddy-to-LiveKit traffic plus `edge` so Docker can publish its TCP fallback and narrow UDP range; Compose maps exactly those media endpoints from the host.

**Tech Stack:** Docker Compose, LiveKit Server v1.8.4, Caddy.

---

### Task 1: Declare external LiveKit candidates

**Files:**
- Modify: `docker/livekit.yaml`
- Modify: `compose.yaml`

- [x] **Step 1: Verify the initial resolved Compose configuration has no LiveKit host port mappings.**

Run: `POSTGRES_PASSWORD=test LIVEKIT_API_KEY=devkey LIVEKIT_API_SECRET=test LIVEKIT_PUBLIC_WS_URL=ws://localhost:8088 docker compose config`

Expected: the `livekit` service has no `ports` section.

- [x] **Step 2: Publish only the selected media endpoints.**

```yaml
rtc:
  tcp_port: 7882
  port_range_start: 50000
  port_range_end: 50100
  use_external_ip: false
```

```yaml
ports:
  - "7882:7882/tcp"
  - "50000-50100:50000-50100/udp"
networks: [edge, private]
```

`--node-ip ${LIVEKIT_NODE_IP}` supplies the server's explicit public address,
avoiding a STUN lookup at runtime. Do not publish PostgreSQL, the LiveKit
management/signalling port 7880, or storage services.

- [x] **Step 3: Resolve and assert the Compose configuration.**

Run: `POSTGRES_PASSWORD=test LIVEKIT_API_KEY=devkey LIVEKIT_API_SECRET=test LIVEKIT_PUBLIC_WS_URL=ws://localhost:8088 LIVEKIT_NODE_IP=127.0.0.1 docker compose config`

Expected: `livekit` exposes exactly TCP 7882 and UDP 50000–50100, while `proxy` remains the sole HTTP entrypoint on TCP 8088.

### Task 2: Deploy and verify the isolated runtime

**Files:**
- Create remotely: `/opt/voice-platform/.env`
- Create remotely: `/opt/voice-platform/*`

- [x] **Step 1: Transfer the reviewed source excluding VCS, local environment files and generated artifacts.**

Run: tar source to `sudo tar -xzf - -C /opt/voice-platform` over SSH.

Expected: remote source has no `.env`, `.git`, `node_modules`, `dist`, or local executable artifact.

- [x] **Step 2: Generate remote-only secrets and start Compose.**

```sh
umask 077
POSTGRES_PASSWORD=$(openssl rand -hex 32)
LIVEKIT_API_SECRET=$(openssl rand -hex 32)
docker compose up -d --build
```

Expected: only root-readable `.env` is created and Compose reports healthy PostgreSQL, completed migration, API, web, proxy and LiveKit services.

- [x] **Step 3: Verify health and published mappings from the server.**

Run: `curl --fail http://127.0.0.1:8088/api/v1/health`, `docker port
voice-platform-livekit-1` and inspect the Docker NAT rules.

Expected: health is successful; TCP 8088/7882 and UDP 50000–50100 are
published, while the database and LiveKit management port remain private.

## Self-review

- The change addresses the external WebRTC media path required by POC-01 without exposing internal databases or the LiveKit API.
- Firewall actions map exactly to public TCP 8088, TCP 7882 and UDP 50000–50100.
- No real media or capacity claim is made until the two-machine POC evidence is captured.
