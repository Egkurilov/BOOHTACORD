package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	coalescepresence "voice-platform/backend/internal/media/coalesce_presence_snapshot"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
	rosterapi "voice-platform/backend/internal/voice/list_connected_participants/api"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
	watchroster "voice-platform/backend/internal/voice/watch_connected_participants"
)

func ConfigureVoiceParticipantRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, presence snapshotlivekitpresence.Client, metrics *httpmetrics.Recorder, apiKey, apiSecret string) {
	gate := coalescepresence.New(presence.WithObserver(metrics), metrics)
	service := listconnectedparticipants.New(rosterpostgres.New(rosterpostgres.NewPoolDatabase(database)), gate, metrics)
	notifier := watchroster.NewNotifier(gate.Invalidate)
	mux.Handle("GET /api/v1/voice/participants", sessionapi.Require(sessions)(rosterapi.NewHandler(service)))
	mux.Handle("GET /api/v1/voice/rosters/events", sessionapi.Require(sessions)(watchroster.NewHandler(service, notifier, sessions, metrics)))
	mux.Handle("POST /internal/livekit/roster", watchroster.NewWebhookHandler(apiKey, apiSecret, notifier))
}
