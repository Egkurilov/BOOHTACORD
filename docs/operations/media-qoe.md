# Media QoE operations and source handoff

Issues #6/#175. Source: `docker/observability/dashboards/media-qoe.json`, UID
`boohtacord-media-qoe`. Existing `boohtacord-traces` remains solely owned by #155;
its JSON is unchanged. Existing datasources: `boohtacord_metrics` (client/incident
OTEL and allowlisted LiveKit), `boohtacord_tempo` (private traces). These are source
bindings, not proof that deployment has provisioned the new dashboard.

## From complaint to an observed stage

1. Narrow time, platform and sender/receiver. Confirm last receipt age, sample age,
   `fresh/stale/legacy` report rates and missing field counters before quality.
2. Check requested target separately from capture settings in private samples.
   Capture FPS settings are not measured capture or encoder FPS. Sender frame
   dimensions come from client diagnostics; receiver dimensions are video-element
   geometry. #159 now pairs selected-layer FPS/bitrate with its interval; capture settings
   remain requested/configured intent. Measured native capture callback/scanout counters
   and requested/applied/delivered revision proof remain unavailable.
3. Compare encoded FPS with selected_layer_bitrate_kbps; total_bitrate_kbps separately
   sums comparable outgoing layer byte intervals. Then inspect loss/window, RTT to SFU and
   jitter. The client adaptation reason `cpu` is not measured SFU saturation.
4. Compare receiver decoded and presented stages. Decoded frames with poor
   presentation are a render symptom; low encode at sender and all receivers is
   a shared-source symptom. None proves a root cause by itself.
5. Select the private sample population from the metric link; inspect up to 100
   authenticated server samples. The table includes #159 interval stats,
   first-frame observation, freeze counters/duration, and collection provenance
   when present; these remain per-sample trace attributes, not Prometheus
   aggregates. Trusted `user.id/session.id` row links open the sole existing
   Traces dashboard. Modern #152 lifecycle traces carry media/flow IDs; old
   server samples only correlate authenticated user/session. Time proximity
   does not prove the samples share a publication.
6. Preserve sanitized paired evidence for the same moving content, then perform
   the existing controlled 720p30 A/B on sender and viewer. Exclude intentional
   static, hidden, paused, unsubscribed and warm-up periods from moving-source
   acceptance. Do not change profiles or restart media automatically from alerts.

## Measurement and retention semantics

`boohtacord_media_*` uses the existing authenticated report API and OTEL pipeline.
Names and field ownership are in `tools/verify/media_qoe/fields.json`. Missing
fields produce availability `missing` and no numeric observation. Report age
unreported is `legacy`; age >5s at receipt is `stale` and adds no quality histogram.
Current charts require known age, latest age at receipt <=5s, total age <60s and
receipt <60s. Legacy reports remain valid and discoverable in private traces.

Labels are fixed platform/direction/source, actual FPS stage, report state,
age provenance, resolution role, availability, and bounded quality/reason codes.
No user/session/room/track/RID or numeric resolution label exists. Field presence
combines states to stay below SDK instrument cardinality limits. Latest anonymous
receipt state is capped at 16 populations; caller pointers/report bodies are not
retained. `playing` does not establish motion/subscribers or a healthy SLO.

FPS is never summed across layers/stages. Each quantile uses rate buckets grouped
by `le`, platform/direction/state/stage/provenance. Histogram quantiles are bucket
estimates, not exact percentiles. Target FPS and dimensions use positive-denominator
sample means; mixed targets can give an intermediate mean, exact intent is in
each private sample. Loss % is a client-calculated 9-12s window estimate, not a
packet-weighted server denominator. Dropped frames/packets lost are cumulative
sample counters, never inferred rates or freeze durations. Adaptation counts count
reports carrying reasons, not downgrade/recovery events or distinct sessions.

Existing Prometheus retention is 7d or 2GB (whichever expires data first); existing
private Tempo compaction retention is 168h. Sampling, outage, volume capacity or
export rejection can omit traces. Admin latest samples remain anonymous and expire
after 60s behind session+administrator ACL and `no-store`. No sample archive or
media storage is introduced. Grafana/Tempo private access and org permissions are
mandatory; filters/unguessable IDs never replace ACL. Do not publish snapshots or
attach raw traces containing real user/session names to issue evidence.

## Diagnostic rules and safe recovery

`media-qoe-alerts.yaml` loads through existing Prometheus rules. All rules are
severity `info`, policy `experimental`, because #157 thresholds are proposed and
hardware/network baseline is absent. Loss >2%, paired FPS ratio <0.9 need >=0.1
known playing samples/s over 5m, sustained 3m. CPU-reason share >50% needs 5m.
Staleness needs a fresh successful private LiveKit snapshot with active screen
publications and no receipt for 60s, sustained 3m; no snapshot is unknown. Snapshot
mirror depends on #5 and an existing native API scrape. No subscribers can explain
missing reports; confirm the complaint before intervention. Thresholds/windows are
reviewable rule constants; change them only with platform baseline and fixtures.

Check freshness first, then publisher/receiver symptoms and SFU transport panels.
SFU RTT/jitter/loss have separate server provenance and `up`/timestamp gating;
snapshot counts publications, not viewers. Preserve voice first and use existing
bounded user recovery. Page only after an agreed baseline and eligible population
denominator exist. No freeze/first-frame/SFU resource rule is fabricated. #159 supplies optional private
first_frame_ms from the first observed Web rVFC callback (observation-start origin),
SDK cumulative freeze_count/freeze_duration_ms, interval decode/encode and jitter-buffer
per-frame averages, retransmission bytes and NACK/PLI/FIR rates. These fields are
validated report/trace fields, not new aggregate metrics or SLO alerts.
stats_window_ms/stats_source pair interval measurements; collection_state describes
collection eligibility, not a network diagnosis. Missing SDK counters stay absent.
presentation_source=unsupported suppresses native presented_fps; framesRendered or
texture uploads do not establish monitor scanout. Web rVFC is compositor observation,
not proof of unique content. Detailed RID/SSRC remains local diagnostics only.
Legacy reports without these optional fields remain accepted. Physical paired-client
and before/after collector overhead acceptance remain NOT_RUN for this packet.

## Delivery, rollback and #155 integration

Before import read existing Grafana UID/source/version, permissions and datasource
versions; save its JSON for rollback and reject concurrent changes. Source only
contains runtime/traces; no preexisting media UID was accessible during this packet.
Import new UID via the established private operator process; never overwrite
`boohtacord-traces`. Save previous JSON/version before any later update. Revert
this source/rule commit or restore saved JSON for rollback; stop rule loading until
the approved thresholds/field delivery are verified. This packet performs no deploy.

Handoff mapping/queries for #155: `fields.json`, `media-qoe.json`, and this guide.
Validate actual source/version, trusted user/session row drilldown and modern
publisher/viewer media flow correlation in the existing Traces view. Capture safe
synthetic screenshots for bad source, CPU report, one bad receiver, render symptoms
and network loss. Verify missing/stale/legacy without green zero. TraceQL and ACL
must be checked against installed Tempo/Grafana; local source checks do not prove it.

Queries cost one 5m bounded histogram/group per panel; no identity joins in metrics.
Trace search is capped at 100 spans/1 matching span per trace; narrow the interval.
CI parses all actual PromQL via pinned promtool and evaluates empty/current/stale/
legacy plus sustained/recovery rules. It does not claim production smoke.
