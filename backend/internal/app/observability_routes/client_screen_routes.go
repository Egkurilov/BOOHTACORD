package observabilityroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	credentialpostgres "voice-platform/backend/internal/media/issue_livekit_credential/postgres"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	reportscreenapi "voice-platform/backend/internal/observability/report_client_screen/api"
)

func ConfigureClientScreenRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, metrics *httpmetrics.Recorder) {
	leaseVerifier := credentialpostgres.New(credentialpostgres.NewPoolDatabase(database))
	mux.Handle("POST /api/v1/voice/screen-metrics", sessionapi.Require(sessions)(reportscreenapi.NewSubmitHandler(metrics, leaseVerifier)))
	mux.Handle("GET /api/v1/admin/screen-metrics", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(reportscreenapi.NewAdminHandler(metrics))))
}
