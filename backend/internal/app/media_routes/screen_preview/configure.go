package screenpreviewapp

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	screenpreviewapi "voice-platform/backend/internal/media/screen_preview/api"
	screenpreviewlivekit "voice-platform/backend/internal/media/screen_preview/livekit"
	screenpreviewpostgres "voice-platform/backend/internal/media/screen_preview/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret string, store screenpreview.Store, events *eventhub.Hub) error {
	publications, err := screenpreviewlivekit.New(screenpreviewlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return fmt.Errorf("configure screen preview publication authority: %w", err)
	}
	authorizer := screenpreviewpostgres.New(screenpreviewpostgres.NewPoolDatabase(database))
	service, err := screenpreview.New(authorizer, publications, store, screenPreviewHints{authorizer: authorizer, events: events})
	if err != nil {
		return fmt.Errorf("configure screen preview service: %w", err)
	}
	screenpreviewapi.RegisterRoutes(mux, sessions, service)
	return nil
}
