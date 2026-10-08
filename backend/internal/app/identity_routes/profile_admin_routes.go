package identityroutes

import (
	"net/http"
	runtimeconfig "voice-platform/backend/internal/config/runtime"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	listmembers "voice-platform/backend/internal/identity/list_members"
	memberpostgres "voice-platform/backend/internal/identity/list_members/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureProfileAdminRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, configuration runtimeconfig.Config, events *eventhub.Hub) error {
	profileReader := listmembers.New(memberpostgres.New(memberpostgres.NewPoolDatabase(database)), events)
	ConfigureProfileRoutes(mux, database, sessions, configuration.PasswordResetLimiter, profileReader, events)
	ConfigureMemberRoutes(mux, database, sessions, events)
	ConfigureAdminAuditRoutes(mux, database, sessions)
	ConfigureAdminAccountListRoutes(mux, database, sessions)
	return ConfigureProfileMediaRoutes(mux, database, sessions, configuration.AttachmentRoot, configuration.UploadLimiter, profileReader, events)
}
