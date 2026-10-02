package identityroutes

import (
	"net/http"
	runtimeconfig "voice-platform/backend/internal/config/runtime"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureProfileAdminRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, configuration runtimeconfig.Config, events *eventhub.Hub) error {
	ConfigureProfileRoutes(mux, database, sessions, configuration.PasswordResetLimiter)
	ConfigureMemberRoutes(mux, database, sessions, events)
	ConfigureAdminAuditRoutes(mux, database, sessions)
	ConfigureAdminAccountListRoutes(mux, database, sessions)
	return ConfigureProfileMediaRoutes(mux, database, sessions, configuration.AttachmentRoot, configuration.UploadLimiter)
}
