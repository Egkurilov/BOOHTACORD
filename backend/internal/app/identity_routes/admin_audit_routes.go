package identityroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	listaudit "voice-platform/backend/internal/identity/list_audit_events"
	listauditapi "voice-platform/backend/internal/identity/list_audit_events/api"
	auditpostgres "voice-platform/backend/internal/identity/list_audit_events/postgres"
)

func ConfigureAdminAuditRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service) {
	service := listaudit.New(auditpostgres.New(auditpostgres.NewPoolDatabase(database)))
	handler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(listauditapi.NewHandler(service)))
	mux.Handle("GET /api/v1/admin/audit", handler)
}
