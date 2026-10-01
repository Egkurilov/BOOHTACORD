package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
	credentialapi "voice-platform/backend/internal/media/issue_livekit_credential/api"
	credentialpostgres "voice-platform/backend/internal/media/issue_livekit_credential/postgres"
	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
)

func ConfigureMediaCredentialRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, signer livekitcredential.Signer) {
	service := issuelivekitcredential.New(credentialpostgres.New(credentialpostgres.NewPoolDatabase(database)), signer)
	handler := sessionapi.Require(sessions)(credentialapi.NewHandler(service))
	mux.Handle("POST /api/v1/voice/leases/{leaseID}/credential", handler)
}
