package main

import (
	"net/http"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
)

func configureRealtimeRoutes(mux *http.ServeMux, sessions authenticatesession.Service, metrics *httpmetrics.Recorder) {
	mux.Handle("GET /api/v1/realtime", sessionapi.Require(sessions)(connectsession.NewHandler(sessions, 0, nil, nil, metrics)))
}
