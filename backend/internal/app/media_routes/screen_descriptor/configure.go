package screendescriptorapp

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	publishapi "voice-platform/backend/internal/media/publish_screen_descriptor/api"
	publishlivekit "voice-platform/backend/internal/media/publish_screen_descriptor/livekit"
	publishpostgres "voice-platform/backend/internal/media/publish_screen_descriptor/postgres"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, origin, privateURL, apiKey, apiSecret string) error {
	writer, err := publishlivekit.New(publishlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return fmt.Errorf("configure screen profile publisher: %w", err)
	}
	repository := publishpostgres.New(publishpostgres.NewPoolDatabase(database), writer)
	publishapi.RegisterRoutes(mux, sessions, repository, origin)
	return nil
}
