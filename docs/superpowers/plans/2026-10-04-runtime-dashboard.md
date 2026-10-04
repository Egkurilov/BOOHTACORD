# Runtime dashboard implementation plan

**Goal:** Make server capacity and BOOHTACORD API health visible in the existing dashboard.
**Architecture:** Keep UID `boohtacord-runtime` and its ten existing panels. Add node-exporter
panels from `prometheus_main`, scoped to the production host `176.108.242.211:9100`.
Application HTTP metrics remain on `boohtacord_metrics`; no new exporters or public ports.
**Stack:** Grafana classic JSON, PromQL, Python unittest, existing Prometheus endpoints.

## Operating brief

- Packet: split_first; route: `tools/verify/runtime_dashboard`, backlog T-052.
- Dependencies: T-010 authentication, T-014 ACL, T-044 attachment security; preserved.
- Baseline: b9116e84; live export version 7 has the same ten queries as repository JSON.
- Scope: exact dashboard JSON, colocated tests, `tools/qa/runtime_queries`, runbook and evidence.
- Ratchets: 100/120 source lines and 8/16 files per leaf. JSON remains one panel per line.
- Stop: focused tests pass, every PromQL executes against live data, existing UID updated,
  visible dashboard checked, source and deployment evidence saved.
- No resource ratio is a hardware capacity promise. Missing samples stay missing.

## Tasks

- [x] Add focused tests before editing JSON: production instance and datasource binding,
  required CPU/RAM/disk/network panels, resource thresholds, unique non-overlapping positions,
  absent samples not converted into zero, and preserved existing API range semantics.
  Run `python -m unittest discover -s tools/verify/runtime_dashboard -v`; new tests must fail.
- [x] Add overview cards, CPU/load/steal/I/O wait, available memory/swap/pressure,
  root filesystem space/inodes, disk throughput, physical NIC traffic and UDP/socket errors.
  Preserve HTTP route detail, add recent latency/error trends, move telemetry internals down.
- [x] Scope node selectors to the production instance; scope physical traffic to enp3s0
  and disk I/O to vda. Mark resources as whole-host measurements including other processes.
  Use MemAvailable for usable RAM and fs avail for free space. Keep no-data neutral.
- [x] Add a read-only PromQL validator with datasource-to-endpoint mapping. Substitute
  Grafana range macros; check live instant queries and a range query for each graph.
  Fail on API errors/non-finite samples; report empty series explicitly without guessing values.
- [x] Re-run focused tests and the native documentation-link check; publish by Grafana's
  authenticated import/update UI using the original UID and verify CPU/RAM/disk cards visually.
- [x] Save observed metrics and checks in evidence, inspect status and sizes, commit only
  scoped paths, and publish source for integration into master.

## Delivery decision

Grafana is already updated in production through its authenticated UI. The follow-up request
adds registration and daily activity metrics; that separate backend packet requires a release.
Deliver both packets through master and the existing signed production pipeline.

## Unavailable data

Current Prometheus has no production container, LiveKit or PostgreSQL exporter series.
Do not substitute metrics from Hetzner or another database. Link to existing stream traces;
runtime dashboard covers host resources, HTTP behavior and telemetry pipeline availability.
