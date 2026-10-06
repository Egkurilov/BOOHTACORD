# Isolated user-flow runtime

Reuses the existing observability Compose and existing browser/Flutter harness.
Go/Node/Flutter/Dart versions: tools/toolchains.json and native lock files.
Collector 0.161.0, Tempo 2.10.3, PostgreSQL 17.6, LiveKit 1.13.7 are pinned.
Synthetic accounts/media only. Capture `git rev-parse HEAD` before each run.
Do not set these variables to production. No release build or deployment required.

## Services

From repository root, with a working local Docker engine:

```sh
docker compose -p boohtacord-tracing-qa -f docker/observability/compose.yaml -f tools/qa/tracing_flow/compose.qa.yaml up -d collector tempo postgres livekit
```

Only start named services. Compose limits RAM/CPU and log growth. Stop after QA;
do not delete unrelated containers, volumes or the Docker/WSL engine.
Default ports bind loopback. For Windows → WSL set TRACE_QA_HOST to the private WSL
address in the WSL environment; use the same isolated namespace/overlay. Keep WSL
alive during the run. If needed, `forward_db.py PRIVATE_WSL_IP --seconds 900` creates
a bounded Windows loopback bridge for the database fixture's loopback guard.

## Runtime environment

Set (replace only QA_HOST, use 127.0.0.1 for a native local engine):

```text
TRACE_QA_COLLECTOR_URL=http://QA_HOST:14318
TRACE_QA_COLLECTOR_METRICS_URL=http://QA_HOST:18889
TRACE_QA_TEMPO_URL=http://QA_HOST:13200
TRACE_QA_SFU_URL=http://QA_HOST:17880
VOICE_PLATFORM_TEST_DATABASE_URL=postgres://trace_qa:synthetic-qa-only@127.0.0.1:15432/trace_qa?sslmode=disable
TEST_DATABASE_URL=<same synthetic DSN>
TRACE_QA_BROWSER=1
TRACE_QA_NATIVE=1
TRACE_QA_FLUTTER_BIN=<installed pinned Flutter executable>
```

With the bridge, use port 15433 in both DSNs. The fixtures create and drop isolated
schemas. Browser test lasts about 125 seconds: do not edit Web source during Vite HMR.

From backend:

```sh
go test -tags tracing_runtime ./internal/observability/ingest_client_traces -run 'TestRuntimeRelay|TestRelayHealth|TestBrowserComponents|TestNativeSDK' -v
go test -tags tracing_runtime ./internal/voice/kick_voice_participant/postgres -run 'TestCommittedCause|TestFailedTransaction|TestDurableWorkerRetry' -v
go test ./internal/realtime/connect_session ./internal/realtime/replay_event/postgres -v
```

Go launches the actual SDK runtimes and the production relay handler. Synthetic
principal injection isolates telemetry; it does not test production login cookies.
Web uses actual Vue message components but synthetic business API responses/video.
Flutter uses the native test engine and actual SDK/frame observer, not a packaged
Windows/Android app. SFU confirms participant absence, not physical peer silence.

For a bounded Tempo outage: stop only `tempo`, run TestRuntimeRelay with
TRACE_QA_EXPECT_TEMPO_OUTAGE=1, wait for its unavailable observation, start `tempo`
within 20 seconds. The test requires accepted data to become queryable within 30s.
Set that flag only during this scenario. Collector retry horizon is 30 seconds.

For actual Collector outage: stop only `collector`, set
TRACE_QA_EXPECT_COLLECTOR_OUTAGE=1 and run `go test -tags tracing_runtime ./internal/observability/ingest_client_traces -run TestActualCollectorOutageReturnsBoundedUnavailable`.
It requires the actual endpoint to be unavailable and relay 503 within four seconds,
with no acceptance receipt. Start `collector` again and rerun TestRuntimeRelay.
This combines with client retry/queue tests; it does not prove physical media quality.

From root:

```sh
python tools/qa/trace_queries/check_trace_queries.py "$TRACE_QA_TEMPO_URL" docker/observability/dashboards/traces.json
docker compose -p boohtacord-tracing-qa -f docker/observability/compose.yaml -f tools/qa/tracing_flow/compose.qa.yaml stop collector tempo postgres livekit
```

Optionally start the existing `prometheus` service (pinned by the base Compose),
then run `check_metric_queries.py http://127.0.0.1:9091 docker/observability/dashboards/traces.json`
from the Docker host. With WSL, execute the Python command inside that distribution.
Wait at least one 15s scrape after TestRelayHealth. Stop this owned service after QA.
This verifies test-stack PromQL, not production Grafana datasource ACL or transformations.

Record PASS/FAIL/NOT_RUN separately for each matrix row. Units/mock exporter results
cannot close device, production Grafana, full voice/media or load acceptance gates.
