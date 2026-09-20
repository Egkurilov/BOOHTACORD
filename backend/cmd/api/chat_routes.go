package main

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
	advancedirectmessagereadcursorapi "voice-platform/backend/internal/chat/advance_direct_message_read_cursor/api"
	advancedirectmessagereadcursorpostgres "voice-platform/backend/internal/chat/advance_direct_message_read_cursor/postgres"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	messageapi "voice-platform/backend/internal/chat/create_text_message/api"
	messagepostgres "voice-platform/backend/internal/chat/create_text_message/postgres"
	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	deletedirectmessageapi "voice-platform/backend/internal/chat/delete_direct_message/api"
	deletedirectmessagepostgres "voice-platform/backend/internal/chat/delete_direct_message/postgres"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	deletehandler "voice-platform/backend/internal/chat/delete_text_message/api"
	deletepostgres "voice-platform/backend/internal/chat/delete_text_message/postgres"
	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	editdirectmessageapi "voice-platform/backend/internal/chat/edit_direct_message/api"
	editdirectmessagepostgres "voice-platform/backend/internal/chat/edit_direct_message/postgres"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	edithandler "voice-platform/backend/internal/chat/edit_text_message/api"
	editpostgres "voice-platform/backend/internal/chat/edit_text_message/postgres"
	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
	listdirectmessagecandidatesapi "voice-platform/backend/internal/chat/list_direct_message_candidates/api"
	listdirectmessagecandidatespostgres "voice-platform/backend/internal/chat/list_direct_message_candidates/postgres"
	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
	listdirectmessagehistoryapi "voice-platform/backend/internal/chat/list_direct_message_history/api"
	listdirectmessagehistorypostgres "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
	listdirectmessagesapi "voice-platform/backend/internal/chat/list_direct_messages/api"
	listdirectmessagespostgres "voice-platform/backend/internal/chat/list_direct_messages/postgres"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
	listhandler "voice-platform/backend/internal/chat/list_text_messages/api"
	listpostgres "voice-platform/backend/internal/chat/list_text_messages/postgres"
	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
	directmessageapi "voice-platform/backend/internal/chat/open_direct_message/api"
	directmessagepostgres "voice-platform/backend/internal/chat/open_direct_message/postgres"
	searchdirectmessagehistory "voice-platform/backend/internal/chat/search_direct_message_history"
	searchdirectmessagehistoryapi "voice-platform/backend/internal/chat/search_direct_message_history/api"
	searchdirectmessagehistorypostgres "voice-platform/backend/internal/chat/search_direct_message_history/postgres"
	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
	searchtextmessagesapi "voice-platform/backend/internal/chat/search_text_messages/api"
	searchtextmessagespostgres "voice-platform/backend/internal/chat/search_text_messages/postgres"
	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	senddirectmessageapi "voice-platform/backend/internal/chat/send_direct_message/api"
	senddirectmessagepostgres "voice-platform/backend/internal/chat/send_direct_message/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func configureChatRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service) {
	service := createtextmessage.New(messagepostgres.New(messagepostgres.NewPoolDatabase(database)))
	editService := edittextmessage.New(editpostgres.New(editpostgres.NewPoolDatabase(database)))
	deleteService := deletetextmessage.New(deletepostgres.New(deletepostgres.NewPoolDatabase(database)))
	listService := listtextmessages.New(listpostgres.New(listpostgres.NewPoolDatabase(database)))
	textMessageSearch := searchtextmessages.New(searchtextmessagespostgres.New(searchtextmessagespostgres.NewPoolDatabase(database)))
	directMessageService := opendirectmessage.New(directmessagepostgres.New(directmessagepostgres.NewPoolDatabase(database)))
	directMessageCandidates := listdirectmessagecandidates.New(listdirectmessagecandidatespostgres.New(listdirectmessagecandidatespostgres.NewPoolDatabase(database)))
	directMessages := listdirectmessages.New(listdirectmessagespostgres.New(listdirectmessagespostgres.NewPoolDatabase(database)))
	directMessageSender := senddirectmessage.New(senddirectmessagepostgres.New(senddirectmessagepostgres.NewPoolDatabase(database)))
	directMessageHistory := listdirectmessagehistory.New(listdirectmessagehistorypostgres.New(listdirectmessagehistorypostgres.NewPoolDatabase(database)))
	directMessageEditor := editdirectmessage.New(editdirectmessagepostgres.New(editdirectmessagepostgres.NewPoolDatabase(database)))
	directMessageDeleter := deletedirectmessage.New(deletedirectmessagepostgres.New(deletedirectmessagepostgres.NewPoolDatabase(database)))
	directMessageReadCursor := advancedirectmessagereadcursor.New(advancedirectmessagereadcursorpostgres.New(advancedirectmessagereadcursorpostgres.NewPoolDatabase(database)))
	directMessageSearch := searchdirectmessagehistory.New(searchdirectmessagehistorypostgres.New(searchdirectmessagehistorypostgres.NewPoolDatabase(database)))
	mux.Handle("POST /api/v1/channels/{channelID}/messages", sessionapi.Require(sessions)(messageapi.NewHandler(service)))
	mux.Handle("GET /api/v1/channels/{channelID}/messages", sessionapi.Require(sessions)(listhandler.NewHandler(listService)))
	mux.Handle("GET /api/v1/channels/{channelID}/search", sessionapi.Require(sessions)(searchtextmessagesapi.NewHandler(textMessageSearch)))
	mux.Handle("PATCH /api/v1/channels/{channelID}/messages/{messageID}", sessionapi.Require(sessions)(edithandler.NewHandler(editService)))
	mux.Handle("DELETE /api/v1/channels/{channelID}/messages/{messageID}", sessionapi.Require(sessions)(deletehandler.NewHandler(deleteService)))
	mux.Handle("POST /api/v1/direct-messages", sessionapi.Require(sessions)(directmessageapi.NewHandler(directMessageService)))
	mux.Handle("GET /api/v1/direct-message-candidates", sessionapi.Require(sessions)(listdirectmessagecandidatesapi.NewHandler(directMessageCandidates)))
	mux.Handle("GET /api/v1/direct-messages", sessionapi.Require(sessions)(listdirectmessagesapi.NewHandler(directMessages)))
	mux.Handle("POST /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(senddirectmessageapi.NewHandler(directMessageSender)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(listdirectmessagehistoryapi.NewHandler(directMessageHistory)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/search", sessionapi.Require(sessions)(searchdirectmessagehistoryapi.NewHandler(directMessageSearch)))
	mux.Handle("PATCH /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(editdirectmessageapi.NewHandler(directMessageEditor)))
	mux.Handle("DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(deletedirectmessageapi.NewHandler(directMessageDeleter)))
	mux.Handle("PUT /api/v1/direct-messages/{directMessageID}/read-cursor", sessionapi.Require(sessions)(advancedirectmessagereadcursorapi.NewHandler(directMessageReadCursor)))
}
