package authorizationroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	permissionsapi "voice-platform/backend/internal/authorization/permissions_api"
	publishpermissionevent "voice-platform/backend/internal/authorization/publish_permission_event"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
	rolepolicypostgres "voice-platform/backend/internal/authorization/role_policy/postgres"
	rolepolicyapi "voice-platform/backend/internal/authorization/role_policy_api"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureRolePermissionRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub) {
	repository := rolepolicypostgres.New(rolepolicypostgres.NewPoolDatabase(database))
	resolver := effectivepermissions.New(repository)
	updater := rolepolicy.New(repository)
	mux.Handle("GET /api/v1/auth/permissions", sessionapi.Require(sessions)(permissionsapi.NewHandler(resolver)))
	mux.Handle("GET /api/v1/admin/roles", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(rolepolicyapi.NewRolesHandler(repository))))
	updateHandler := publishpermissionevent.NewHandler(rolepolicyapi.NewUpdateHandler(updater), events)
	mux.Handle("PUT /api/v1/admin/roles/{role}/permissions", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(updateHandler)))
}
