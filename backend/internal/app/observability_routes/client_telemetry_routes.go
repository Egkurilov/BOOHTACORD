package observabilityroutes

import (
	"net/http"
	runtimeconfig "voice-platform/backend/internal/config/runtime"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	ingestclienttraces "voice-platform/backend/internal/observability/ingest_client_traces"
)

func ConfigureClientTelemetryRoutes(mux *http.ServeMux, sessions authenticatesession.Service, configuration runtimeconfig.Config) {
	endpoint := ingestclienttraces.NewHandler(configuration.TelemetryEndpoint, configuration.TelemetryAuth, nil)
	mux.Handle("POST /api/v1/telemetry/traces", configuration.TelemetryLimiter.Middleware(sessionapi.Require(sessions)(endpoint)))
}
