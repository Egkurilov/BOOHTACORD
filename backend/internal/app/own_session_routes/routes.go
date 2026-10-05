package ownsessionroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	listapi "voice-platform/backend/internal/identity/list_own_sessions/api"
	listpostgres "voice-platform/backend/internal/identity/list_own_sessions/postgres"
	revokeapi "voice-platform/backend/internal/identity/revoke_own_sessions/api"
	revokepostgres "voice-platform/backend/internal/identity/revoke_own_sessions/postgres"
	sessionrealtime "voice-platform/backend/internal/identity/revoke_own_sessions/realtime"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func Register(mux *http.ServeMux, pool *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub) {
	require := sessionapi.Require(sessions)
	mux.Handle("GET /api/v1/me/sessions", require(listapi.New(listpostgres.New(pool))))
	handler := require(revokeapi.New(sessionrealtime.Store{Inner: revokepostgres.New(pool), Events: events}))
	mux.Handle("DELETE /api/v1/me/sessions/{sessionID}", handler)
	mux.Handle("POST /api/v1/me/sessions/revoke-others", handler)
}
