package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
	leaseapi "voice-platform/backend/internal/voice/acquire_voice_lease/api"
	leasepostgres "voice-platform/backend/internal/voice/acquire_voice_lease/postgres"
	releasevoicelease "voice-platform/backend/internal/voice/release_voice_lease"
	releaseapi "voice-platform/backend/internal/voice/release_voice_lease/api"
	releasepostgres "voice-platform/backend/internal/voice/release_voice_lease/postgres"
)

func ConfigureVoiceLeaseRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, maintenance maintenanceadmission.Service) {
	service := acquirevoicelease.New(leasepostgres.New(leasepostgres.NewPoolDatabase(database)))
	handler := sessionapi.Require(sessions)(maintenanceadmission.Middleware(maintenance)(leaseapi.NewHandler(service)))
	release := releasevoicelease.New(releasepostgres.New(releasepostgres.NewPoolDatabase(database)))
	releaseHandler := sessionapi.Require(sessions)(releaseapi.NewHandler(release))
	mux.Handle("POST /api/v1/voice/channels/{channelID}/leases", handler)
	mux.Handle("DELETE /api/v1/voice/leases/{leaseID}", releaseHandler)
}
