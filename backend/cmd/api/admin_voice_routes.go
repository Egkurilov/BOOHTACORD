package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
	kickapi "voice-platform/backend/internal/voice/kick_voice_participant/api"
	kickpostgres "voice-platform/backend/internal/voice/kick_voice_participant/postgres"
)

func configureAdminVoiceRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service) {
	service := kickvoiceparticipant.New(kickpostgres.New(kickpostgres.NewPoolDatabase(database)))
	handler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(kickapi.NewHandler(service)))
	mux.Handle("POST /api/v1/admin/accounts/{accountID}/voice-kick", handler)
}
