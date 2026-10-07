# Issues #6/#175: source verification evidence

Date: 2026-10-07. Branch: `codex/issues-6-175-media-qoe`.
Baseline: `6b8ffa5e5c266d42a534f294c18e5a282139bfa9`. Source-only handoff; issues remain open.

## Packets and observed checks

- `split_first`, T-052 report aggregate leaf + existing report API edges; T-030 behavior preserved.
- PASS: nearest Go tests report_client_screen (aggregate/API/profile), http_metrics and observability_routes; focused go vet.
- PASS: OTLP payload regression and actual official pinned collector 0.161.0 loopback export/scrape.
- PASS: promtool 3.11.2 parses four diagnostic alerts and 21 materialized actual dashboard PromQL expressions.
- PASS: evaluator fixtures empty/current/stale/legacy, actual-stage buckets, single bad sample, sustained loss, recovery, target gap, CPU reason, missing snapshot and telemetry recovery.
- PASS: Python dashboard/source mapping, fixed private query limits/links, missing values, SFU freshness, CI rule wiring.
- NOT_RUN: Docker Desktop engine unavailable; native official pinned Windows binaries used for local checks.

## CI composition revalidation

- Initial PR CI failed the existing LiveKit artifact hash check because compose and Prometheus rule configuration intentionally changed. Updated those two normalized evidence SHA256 bindings with an explicit source review; checker/model unchanged.
- PASS: 15 LiveKit network tests; full `python -m tools.ci.native.contracts`, including 174 Python tests (one pre-existing skip), contracts/traceability/link/topology/workflow/Compose checks. Source correction does not imply live acceptance.

## Versions and export proof

- Collector source pin 0.161.0, native output `otelcol version 0.161.0`.
- Collector exe SHA256: `A10EE585051BC6F822E41936FF91CA593CF38A0CA9D1089479BB0440A5E41805`.
- Prometheus/promtool source and native pin 3.11.2; Tempo source pin 2.10.3.
- #5 agent independently verified pinned collector snapshot/freshness names; snapshot and API collection require fresh successful age<45s, and remain absent without native API scrape.
- Export byte names: `boohtacord_media_*` histograms become `_bucket/_sum/_count`; counters acquire `_total`; gauges retain names.
- Synthetic scrape byte SHA256: `196ff193bd4fe703eee1db84ef7a287c2a521c428989a27600abe39260e98dc9`; no real identities or samples used.
- Actual export test is loopback-only (14318/18889), no production metrics writes. Binary/raw bytes live in ignored `.out/media-qoe-*`.

## Source SHA256

- `docker/observability/dashboards/media-qoe.json`: `77891bd3244aff2881a45aadcec155e655c37092b6dde18984805879aff0524`
- `docker/observability/media-qoe-alerts.yaml`: `454af773d9bf10d4871d265d5749f2e3b5987a9179c15aeed4565c83c966bd75`
- `backend/internal/observability/report_client_screen/aggregate/instruments.go`: `54c57ea20528a463b177dfa98ab0349261d6e37b6ce90af80e528d36a6d618e2`
- `backend/internal/observability/report_client_screen/aggregate/observe.go`: `6a01542dbfe41474746055e89679a8e751aa06f7426811633703e513a0a43cb4`

## Requirement coverage and remaining acceptance

| Requirement | Source result / remaining evidence |
| --- | --- |
| #6 loss/RTT/jitter/drop/target/sample age | Implemented fixed bounded histograms and paired target ratios; absent fields do not observe zero. Drop is cumulative sample, not inferred rate. |
| #6 sender/receiver/platform/stage | Encoded/decoded/presented separated; state cohorts and known/legacy age retained. Not user/population counts. |
| #6 retention/access >60s | Existing Prometheus 7d/2GB and private Tempo168h; correlated drop/packets now preserved in media.sample; admin latest60s unchanged. Actual retained production availability NOT_RUN. |
| #6 loss/target discrepancy | Window9-12s accepted; diagnostic 2%/0.9 candidates with sample denominator and sustained3m. Baseline approval still pending #157. |
| #175 source/provisioning/version | New separate boohtacord-media-qoe source; no preexisting media source found in repo. Live source/provisioning/old JSON/version save NOT_RUN due access. |
| #175 active publications/viewers | Publication query consumes #5 private native snapshot bridge, absent without bridge/scrape; participant count is not viewer count. Viewer population unavailable. |
| #175 actual/target/FPS/bitrate/loss/RTT/jitter/drop | Real emitted fields delivered; target/dimension means avoid misleading histogram-interpolated intent. Quantiles explicitly approximate. |
| #175 requested/applied/delivered, quality revision | Requested target and reported dimensions shown. Applied descriptor/quality revision not in report; #159 dependency unavailable. |
| #175 per-layer/codec/encode/decode time/transport | #159 emits selected-layer/retransmitted bitrate, per-frame encode/decode, and jitter-buffer measurements in authenticated `media.sample` spans. The QoE table exposes those trace-only values; no Prometheus aggregates, layer IDs, or codec plan are claimed. |
| #175 first frame/switch/freeze distributions | #159 emits first-frame observation and cumulative freeze count/duration in authenticated spans; QoE drilldown exposes those per-sample values. Population distributions, switch duration, and freeze ratio remain unavailable; no metrics or alerts are fabricated. |
| #175 downgrade/recovery reason/count | Bounded adaptation report reason exists; event count/quality revision unavailable. Reports are not events. |
| #175 SFU CPU/throttling/NIC/UDP | #171 container attribution absent; no fabricated metric/alert. Existing allowlisted LiveKit network histograms retain separate server provenance. |
| #175 alerts | Four bounded sustained info/experimental diagnostic rules evaluated locally. Freeze/firstframe/saturation rules await real fields and agreed #157 baseline. Controlled production firing/recovery NOT_RUN. |
| #175 metric to private trace | Population filter -> up to100 trusted server samples -> existing Traces UID row link. No identity labels. Production ACL/TraceQL installed-datasource validation NOT_RUN. |
| #175 #155 queries/field mapping | fields.json + source/guide handoff; sole Traces UID unchanged. Modern media/flow correlation stays in existing Traces. Legacy sample has no media session/layer/revision. |
| #175 CI fixture semantics | Actual PromQL parser/evaluator coverage added to CI contracts using pinned container. No assertion that source lint proves production. |
| #175 synthetic media scenarios/screenshots | Local metric evaluator scenarios only. Paired bad-source/CPU/one receiver/render/network-loss runtime/screenshots NOT_RUN. |

## Read-only deployed observations and rollback

- Root read-only GET Grafana `/api/health`: version13.0.2, commit3fcdbc5a, databaseok.
- Grafana search and datasource APIs401; existing browser inventory twice failed request-header policy.
- NOT_RUN: authenticated media UID/source/version/provisioning, deployed Prometheus/Tempo versions, datasource query execution, permissions and production smoke.
- No dashboard/rule import, API production mutation, APK/Windows build, media load or physical capacity claim.
- Rollback: revert this source/rule change or restore operator-saved existing media JSON/version after a future authorized import. Live previous media JSON could not be saved here; do not overwrite concurrent changes.

Slavik Gym report: route=report_client_screen/aggregate + media-qoe source; packet=aggregate,dashboard-source,read-only-verification; tokens=estimated:19000; method=manual_estimate; driver=bounded telemetry + honest QoE semantics; next_split=#159/#171 field delivery and #157 baseline, then authorized deploy/#155 integration.

## #159 trace-field dashboard follow-up

2026-10-07 source-only follow-up: the private sample table now selects the
validated #159 interval measurement and collection/presentation provenance
fields from `media.sample`. These remain optional trace attributes and are not
added to Prometheus panels or rules. `tools/verify/media_qoe/test_dashboard.py`
checks mapping to the report contract, table selection, and absence from
PromQL expressions. Focused dashboard tests and JSON parsing PASS; pinned
Prometheus container checks are NOT_RUN because the local Docker Desktop engine
is unavailable. Grafana/Tempo datasource execution, access/ACL, live import,
paired media scenarios, screenshots, production alerts, and #155 integration
remain NOT_RUN.
