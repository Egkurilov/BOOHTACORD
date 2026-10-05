package channelsroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	closure "voice-platform/backend/internal/channel/inspect_voice_closure"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func ConfigureVoiceClosureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, presence closure.Presence) {
	service := closure.New(closure.Repository{Database: database}, presence)
	mux.Handle("GET /api/v1/admin/voice-channels/{channelID}/closure", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(closure.Handler(service))))
}
