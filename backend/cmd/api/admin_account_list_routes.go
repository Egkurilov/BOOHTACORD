package main

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	listaccounts "voice-platform/backend/internal/identity/list_admin_accounts"
	listaccountsapi "voice-platform/backend/internal/identity/list_admin_accounts/api"
	accountlistpostgres "voice-platform/backend/internal/identity/list_admin_accounts/postgres"
)

func configureAdminAccountListRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service) {
	service := listaccounts.New(accountlistpostgres.New(accountlistpostgres.NewPoolDatabase(database)))
	handler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(listaccountsapi.NewHandler(service)))
	mux.Handle("GET /api/v1/admin/accounts", handler)
}
