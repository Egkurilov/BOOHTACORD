# BOOHTACORD observability

The API records one server span per named HTTP route, one span per realtime
connection, and one span per voice background attempt. Web and Flutter clients
record explicit API, voice, realtime and screen operations. Span names are fixed.
HTTP clients send W3C `traceparent` to the API; the server continues that trace
and preserves its parent span ID. Flutter sends the header during WebSocket
handshakes. Browser WebSocket cannot set a custom HTTP header, so it sends the
W3C `traceparent` and optional `tracestate` as bounded handshake query parameters, which the API
extracts only on the realtime upgrade. Web voice operations explicitly restore
their span context around API calls made after `await`.
The client relay strips request supplied attributes and links before export,
except for the bounded `audio.input.switch` outcome. That span keeps only
`platform=web|android|ios|windows|macos` (derived from the validated relay
platform), `phase=prejoin|active|reconnect`, and
`result=success|fallback|error`. Device IDs, device labels and audio are never
included in this outcome.
It keeps at most four fixed `app.client.<operation>.started/completed/failed`
events per allowlisted span, without event attributes. This limits accidental
leakage of message content, IDs and tokens into Tempo.

## Production wiring

The infrastructure runs in `/opt/boohtacord-observability` on
`167.233.56.32`. Its HTTPS ingress is `https://metric.bootybay.ru/v1/traces`
and `/v1/metrics`. The collector, Tempo and Prometheus listen only on the
server's loopback or Docker network. Tempo retains traces for seven days;
Prometheus retains metrics for seven days or 2 GB, whichever is reached first.

Set these in the **API host's** private `.env` before publishing the changed
API image:

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=https://metric.bootybay.ru
OTEL_INGEST_AUTH=Basic <base64-of-otel-colon-ingest-password>
```

The ingest password is held on the observability server in
`/root/.config/boohtacord-observability/ingest-password` (root only). Use it to
form the HTTP Basic header. Never add that password or the Basic header to a
client binary, repository, Grafana panel, log or trace. The browser and Flutter
clients send same-origin authenticated OTLP batches to
`POST /api/v1/telemetry/traces`; the API supplies the server-side collector
credential. The route requires a session, Origin check and rate limit.

The production API and web client run at `v.bootybay.ru` on `176.108.242.211`.
The API joins a dedicated `telemetry-egress` Docker network for outbound OTLP;
PostgreSQL and other management interfaces remain on the internal network.
The API container maps `metric.bootybay.ru` to `167.233.56.32` while retaining
the domain for HTTPS certificate validation.

## Dashboards and incident use

- [Runtime](https://grafana.fa.shaneque.ru/d/boohtacord-runtime/boohtacord-7c-runtime): three target health checks, API request totals and 5xx share for the selected time range, span rate, route traffic and p95 latency, status and route tables, Tempo live traces and storage process memory.
- [Traces](https://grafana.fa.shaneque.ru/d/boohtacord-traces/boohtacord-7c-traces): HTTP requests, errors, slow requests, client actions and application event searches. Trace IDs open the full waterfall and its event timeline.

Successful state-changing API responses add a fixed `app.*` event to the
existing HTTP span; 4xx and 5xx responses use `.rejected` and `.failed`.
Web and Flutter voice, realtime and screen operations add lifecycle events.
The event panels find spans containing these events; open a trace to inspect
the event name and time. A successful API response indicates acceptance, not
necessarily a distinct database change for an idempotent request. Realtime
broadcasts are not recorded individually because they can be frequent and
contain private identifiers.

The fixed operational paths `/metrics`, `/api/v1/health`,
`/api/v1/maintenance`, `/api/v1/auth/session`, `/api/v1/telemetry/traces`,
`/api/v1/voice/screen-metrics`, `/api/v1/voice/rosters/events` and the two
`/internal/` hooks bypass request spans, HTTP request counters and access logs.
The browser and Flutter OTLP exporters use untraced transports. Application
actions, including auth attempts and voice lease changes, remain observable.

Start with target health, then request rate, error rate and p95 duration.
Open a trace for the affected route or operation. Compare voice joins,
reconnects and screen share spans to the corresponding API route span. A missing
signal is a deployment or exporter problem; it is not evidence of a healthy
feature. Investigate collector and Tempo health and the API environment before
using empty panels to make an SLO decision.

The HTTP metrics use bounded method, route template and status labels. No
usernames, DM identifiers, message bodies, tokens or raw URL paths are
recorded. Existing application logs remain local; this deployment does not
create a log collection pipeline.

Grafana 13 serves plugin modules through its own `/public/plugins/` route.
The Grafana nginx virtual host must proxy `/public/` to `127.0.0.1:3000`;
serving `/usr/share/grafana/public` directly breaks the Tempo plugin. After
repairing a previously cached 404 response, clear the browser cache once.

## Verification

`docker compose -f /opt/boohtacord-observability/compose.yaml ps` shows the
three infrastructure services. On the server, Tempo `/ready` listens on
`127.0.0.1:3200` and Prometheus `/-/ready` on `127.0.0.1:9091`. The synthetic
OTLP smoke tool is `tools/qa/otlp_smoke/smoke_otlp.py`; it requires an
authorized HTTP Basic password file and emits metadata only. See the evidence
record for the last verified results and outstanding production checks.
