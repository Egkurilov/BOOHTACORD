package main

import (
	"net/http"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	reportscreenapi "voice-platform/backend/internal/observability/report_client_screen/api"
)

func configureClientScreenRoutes(mux *http.ServeMux, sessions authenticatesession.Service, metrics *httpmetrics.Recorder) {
	mux.Handle("POST /api/v1/voice/screen-metrics", sessionapi.Require(sessions)(reportscreenapi.NewSubmitHandler(metrics)))
	mux.Handle("GET /api/v1/admin/screen-metrics", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(reportscreenapi.NewAdminHandler(metrics))))
}
