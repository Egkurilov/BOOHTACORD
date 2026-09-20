package main

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
	signalapi "voice-platform/backend/internal/media/authorize_livekit_signal/api"
	signalpostgres "voice-platform/backend/internal/media/authorize_livekit_signal/postgres"
)

func configureMediaRevocationRoutes(mux *http.ServeMux, database *pgxpool.Pool, config authorizelivekitsignal.Config, maintenance maintenanceadmission.Service) error {
	service, err := authorizelivekitsignal.New(config, signalpostgres.New(signalpostgres.NewPoolDatabase(database)))
	if err != nil {
		return fmt.Errorf("configure livekit signal admission: %w", err)
	}
	mux.Handle("GET /internal/media-admission", maintenanceadmission.Middleware(maintenance)(signalapi.NewHandler(service)))
	return nil
}
