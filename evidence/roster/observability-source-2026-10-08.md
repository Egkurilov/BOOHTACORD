# #271 roster observability source checks

Base: `b0bbe27a4618eb831dd33e1e4f2b0ea98488921b`.
Source PASS: ten actual Grafana PromQL expressions and three sustained private
alert rules parsed by pinned `prom/prometheus:v3.11.2` promtool.
Synthetic PASS: idle does not alert; continuous initial failures alert; active
watchers without success alert; enabled exporter with missing roster marker alerts.
Four real promtool fixtures passed. These are synthetic operational signals,
not a media load test or production capacity baseline.

Focused Python: two tests PASS. Native contracts/traceability PASS, 90 public
operations, 39 requirements. Full tools regression: 243 tests, one pre-existing
skip; no failures. Compose interpolation PASS. Seven-boundary on-call map PASS.
CI runs the real expressions and these synthetic rules on future changes.

No public management interface or new backend scrape target added. Backend agent
owns the bounded OTel observations exported through existing authenticated pipeline.
Historical network evidence remains immutable; intentional rule wiring has a
separate source-only revalidation supplement. No physical evidence is promoted.

Production Grafana import, fresh exported series, alert delivery and correlated
authorized REST/SSE recovery: NOT_RUN. Additional p95/calls-per-watcher warnings
need a measured baseline. #272 owns release/device acceptance.
