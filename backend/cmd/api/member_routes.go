package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	listmembers "voice-platform/backend/internal/identity/list_members"
	listmembersapi "voice-platform/backend/internal/identity/list_members/api"
	memberpostgres "voice-platform/backend/internal/identity/list_members/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func configureMemberRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub) {
	service := listmembers.New(memberpostgres.New(memberpostgres.NewPoolDatabase(database)), events)
	mux.Handle("GET /api/v1/members", sessionapi.Require(sessions)(listmembersapi.NewHandler(service)))
	mux.Handle("GET /api/v1/members/{userID}", sessionapi.Require(sessions)(listmembersapi.NewDetailHandler(service)))
}
