package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	screendescriptorapp "voice-platform/backend/internal/app/media_routes/screen_descriptor"
	session "voice-platform/backend/internal/identity/authenticate_session"
)

func ConfigureScreenDescriptorRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, origin, privateURL, apiKey, apiSecret string) error {
	return screendescriptorapp.ConfigureRoutes(mux, database, sessions, origin, privateURL, apiKey, apiSecret)
}
