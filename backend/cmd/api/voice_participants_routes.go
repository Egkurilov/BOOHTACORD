package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
	rosterapi "voice-platform/backend/internal/voice/list_connected_participants/api"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
	watchroster "voice-platform/backend/internal/voice/watch_connected_participants"
)

func configureVoiceParticipantRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, presence snapshotlivekitpresence.Client, metrics *httpmetrics.Recorder, apiKey, apiSecret string) {
	service := listconnectedparticipants.New(rosterpostgres.New(rosterpostgres.NewPoolDatabase(database)), presence, metrics)
	notifier := watchroster.NewNotifier()
	mux.Handle("GET /api/v1/voice/participants", sessionapi.Require(sessions)(rosterapi.NewHandler(service)))
	mux.Handle("GET /api/v1/voice/rosters/events", sessionapi.Require(sessions)(watchroster.NewHandler(service, notifier)))
	mux.Handle("POST /internal/livekit/roster", watchroster.NewWebhookHandler(apiKey, apiSecret, notifier))
}
