# Autonomous client acceptance implementation plan

> Execute inline in bounded packets using the native project commands.

**Goal:** Exercise the remaining software acceptance autonomously with real TLS,
cookies, API, PostgreSQL, WebSocket and Tempo, preserving physical gates.

**Architecture:** A disposable Linux stack binds only loopback. Two independent
Chromium contexts open the production Vue application without API mocks. Synthetic
accounts and a synthetic TEXT channel are created only in the disposable database.
No production account, guild name, microphone or existing database is mutated.

**Tech stack:** Go 1.26.4, PostgreSQL 17.6, Caddy 2.10.0, Tempo 2.10.3, Playwright.

## Operating brief

Route `review_gate`; leaf `tools/qa/client_lifecycle`; T-052/T-050 and guild
contracts are preserved. Scope: exact production routes in OpenAPI, App.vue,
guild settings and owned-session components. Ratchet: target 100/hard 120 lines,
target 8/hard 16 production files/tests. Stop when repeated real-stack scenarios
and cleanup pass, evidence is recorded and remaining physical criteria are explicit.

## Task 1 — Safety and disposable stack

- [ ] Add `test_services.py` first: reject non-loopback browser origins, nonlocal
  Docker daemons and attempts to remove a container with another ownership label.
- [ ] Implement `services.py`, `stack.py` and `run.py`: create uniquely named
  labeled containers, TLS proxy and owned API process; run migrations/bootstrap
  with a random synthetic password via stdin; release every owned resource.
- [ ] Run `python -m unittest tools.qa.client_lifecycle.test_services`.

## Task 2 — Actual production browser journey

- [ ] Add `request.mjs`, `guild.mjs`, `sessions.mjs`, `scenario.mjs`.
- [ ] Login via real authentication UI; create TEXT through the real admin API;
  save guild settings via the production component; verify live second-client
  name/title, stale-revision 409, member/Origin denials and welcome on both clients.
- [ ] Check reload/reconnect without duplicate welcome; revoke a real second
  session via the production settings UI; verify invalid old cookie/socket and
  valid initiating session. Retain synthetic screenshots and a bounded report.
- [ ] Execute `python -m tools.qa.client_lifecycle.run` on the isolated Linux host.
  No retry of failed assertions. Inspect and repair any actual defect before rerun.

## Task 3 — Observability and restart

- [ ] Add `telemetry.py`: query the disposable Tempo for the actual register root
  and welcome child; assert parent/trace identity, server-created subject,
  bounded lifecycle metric labels and absence of password/body/guild name.
- [ ] Restart only the owned API process; reread the persisted guild profile and
  confirm one welcome in the same disposable PostgreSQL database.
- [ ] Repeat from a fresh database and compare the independent reports.

## Task 4 — Evidence and exact limitations

- [ ] Record commands, source hash, counts, browser screenshots and cleanup in
  `evidence/autonomous-client-acceptance-2026-10-05.md`.
- [ ] Map #63/#95/#100/#101/#102/#105/#107/#110 to executed software checks and
  remaining device, production or acoustic requirements. Synthetic speech/tone,
  blocked UDP/TCP and emulator UI are never renamed physical/home/hotspot PASS.
- [ ] Validate focused native checks, contracts, spec traceability and links.
- [ ] Commit explicit files on `codex/autonomous-acceptance`; merge only after CI.
