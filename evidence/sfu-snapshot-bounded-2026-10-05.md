# Bounded SFU snapshot measurement

Status: PASS. Date: 2026-10-05. Issue: #81.
Executor: GitHub Ubuntu 24.04; owned Go/PostgreSQL/LiveKit fixture.
Source merge: `7242d73dbbf4449f76be206c6fb7e9691e64b333`.
Head: `c7f7818f89a57bb414747c1d7be9a1da73f0e875`.
[Actual measurement](https://github.com/Egkurilov/BOOHTACORD/actions/runs/37360552425).

| Virtual authenticated HTTP observers | Actual RoomService calls | Calls/sec | HTTP p95 ms |
|---|---|---|---|
| 1 | 1 | 120.992 | 7.873 |
| 20 | 1 | 17.487 | 42.601 |
| 100 | 1 | 5.194 | 49.512 |

[The uncached baseline](sfu-snapshot-baseline-2026-10-05.md) measured 1/20/100
actual calls. Measurements justified single-flight and a 250 ms metadata TTL.
The retained scope is bounded to one canonical room set; maps are copied.
Authentication, initial/final PostgreSQL visibility and no-store remain per response.
Canceled callers do not cancel other callers' shared fetch; its deadline is 3 seconds.
Expired snapshots are discarded. SFU outage after TTL returns 503; recovery returns 200.
The harness explicitly expires TTL before asserting unavailability, including fast shutdown.

Raw receipt: local `critical-next-five-issues/sfu-current/report.json` and run artifact.
API SHA-256: `5f3f182adaed10b7b5ce98f021719c1e1491f9813abfc3484354a172b7333130`.
Owned resources removed; no production volumes or accounts used.
These observers share an authenticated session and query one absent SFU room.
This is HTTP fan-out evidence; it proves no publisher count or physical media capacity.
Live cached account/lease visibility is covered by focused tests and the separate client receipt.
