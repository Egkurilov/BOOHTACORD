package messagesocialroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	reactions "voice-platform/backend/internal/chat/change_message_reaction"
	reactionapi "voice-platform/backend/internal/chat/change_message_reaction/api"
	reactionpg "voice-platform/backend/internal/chat/change_message_reaction/postgres"
	reactionevents "voice-platform/backend/internal/chat/change_message_reaction/realtime"
	pins "voice-platform/backend/internal/chat/change_text_pin"
	pinapi "voice-platform/backend/internal/chat/change_text_pin/api"
	pinpg "voice-platform/backend/internal/chat/change_text_pin/postgres"
	pinevents "voice-platform/backend/internal/chat/change_text_pin/realtime"
	readreactions "voice-platform/backend/internal/chat/list_message_reactions"
	readreactionapi "voice-platform/backend/internal/chat/list_message_reactions/api"
	readreactionpg "voice-platform/backend/internal/chat/list_message_reactions/postgres"
	readpins "voice-platform/backend/internal/chat/list_text_pins"
	readpinapi "voice-platform/backend/internal/chat/list_text_pins/api"
	readpinpg "voice-platform/backend/internal/chat/list_text_pins/postgres"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func Register(mux *http.ServeMux, pool *pgxpool.Pool, sessions session.Service, hub *eventhub.Hub) {
	writer := reactionevents.New(reactions.New(reactionpg.New(pool)), hub)
	reader := readreactions.New(readreactionpg.New(pool))
	textReader := sessionapi.Require(sessions)(readreactionapi.NewHandler(reader, false))
	directReader := sessionapi.Require(sessions)(readreactionapi.NewHandler(reader, true))
	textWriter := sessionapi.Require(sessions)(reactionapi.NewHandler(writer, false))
	directWriter := sessionapi.Require(sessions)(reactionapi.NewHandler(writer, true))
	mux.Handle("GET /api/v1/channels/{channelID}/message-reactions", textReader)
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/message-reactions", directReader)
	mux.Handle("PUT /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}", textWriter)
	mux.Handle("DELETE /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}", textWriter)
	mux.Handle("PUT /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}", directWriter)
	mux.Handle("DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}", directWriter)
	pinner := pinevents.New(pins.New(pinpg.New(pool)), hub)
	pinWriter := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(pinapi.NewHandler(pinner)))
	mux.Handle("PUT /api/v1/admin/text-channels/{channelID}/pins/{messageID}", pinWriter)
	mux.Handle("DELETE /api/v1/admin/text-channels/{channelID}/pins/{messageID}", pinWriter)
	mux.Handle("GET /api/v1/channels/{channelID}/pins", sessionapi.Require(sessions)(readpinapi.NewHandler(readpins.New(readpinpg.New(pool)))))
}
