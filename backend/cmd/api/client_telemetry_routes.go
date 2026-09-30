package main

import (
	"net/http"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	ingestclienttraces "voice-platform/backend/internal/observability/ingest_client_traces"
)

func configureClientTelemetryRoutes(mux *http.ServeMux, sessions authenticatesession.Service, configuration runtimeConfiguration) {
	endpoint := ingestclienttraces.NewHandler(configuration.telemetryEndpoint, configuration.telemetryAuth, nil)
	mux.Handle("POST /api/v1/telemetry/traces", configuration.telemetryLimiter.Middleware(sessionapi.Require(sessions)(endpoint)))
}
