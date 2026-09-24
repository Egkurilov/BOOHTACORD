package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func configureChatAndRealtimeRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, metrics *httpmetrics.Recorder, events *eventhub.Hub) {
	configureChatRoutes(mux, database, sessions, events)
	configureRealtimeRoutes(mux, sessions, metrics, events)
}

func configureRealtimeRoutes(mux *http.ServeMux, sessions authenticatesession.Service, metrics *httpmetrics.Recorder, events *eventhub.Hub) {
	mux.Handle("GET /api/v1/realtime", sessionapi.Require(sessions)(connectsession.NewHandlerWithEvents(sessions, 0, nil, nil, metrics, events)))
}
