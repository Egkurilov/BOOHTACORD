package guildroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	guildsettingsapi "voice-platform/backend/internal/guild/update_settings/api"
	guildsettingspostgres "voice-platform/backend/internal/guild/update_settings/postgres"
	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func Register(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub, observer *guildlifecycle.Observer) {
	handler := guildsettingsapi.Handler{Store: guildsettingspostgres.New(database), Observer: observer, Events: events}
	mux.HandleFunc("GET /api/v1/guild-profile", handler.Public)
	mux.Handle("GET /api/v1/admin/guild-settings", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(http.HandlerFunc(handler.Read))))
	mux.Handle("PATCH /api/v1/admin/guild-settings", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(http.HandlerFunc(handler.Patch))))
}
