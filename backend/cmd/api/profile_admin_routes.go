package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
)

func configureProfileAdminRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, configuration runtimeConfiguration) error {
	configureProfileRoutes(mux, database, sessions, configuration.passwordResetLimiter)
	configureMemberRoutes(mux, database, sessions)
	configureAdminAuditRoutes(mux, database, sessions)
	configureAdminAccountListRoutes(mux, database, sessions)
	return configureProfileMediaRoutes(mux, database, sessions, configuration.attachmentRoot, configuration.uploadLimiter)
}
