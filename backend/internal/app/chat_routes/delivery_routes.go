package chatroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	api "voice-platform/backend/internal/chat/lookup_message_delivery/api"
	postgres "voice-platform/backend/internal/chat/lookup_message_delivery/postgres"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func configureDeliveryRoutes(mux *http.ServeMux, pool *pgxpool.Pool, sessions auth.Service) {
	store := postgres.New(pool)
	mux.Handle("GET /api/v1/channels/{channelID}/message-delivery/{clientMessageID}", sessionapi.Require(sessions)(api.New(store, false)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/message-delivery/{clientMessageID}", sessionapi.Require(sessions)(api.New(store, true)))
}
