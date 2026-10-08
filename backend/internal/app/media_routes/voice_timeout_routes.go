package mediaroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
	timeoutapi "voice-platform/backend/internal/voice/manage_voice_timeout/api"
	timeoutpostgres "voice-platform/backend/internal/voice/manage_voice_timeout/postgres"
)

func configureVoiceTimeoutRoutes(mux *http.ServeMux, pool *pgxpool.Pool, sessions auth.Service) {
	handler := timeoutapi.NewHandler(timeout.New(timeoutpostgres.New(pool)))
	admin := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(handler))
	mux.Handle("PUT /api/v1/admin/accounts/{accountID}/voice-timeout", admin)
	mux.Handle("DELETE /api/v1/admin/accounts/{accountID}/voice-timeout", admin)
	mux.Handle("GET /api/v1/accounts/{accountID}/voice-timeout", sessionapi.Require(sessions)(handler))
}
