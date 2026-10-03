package channelsroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/channel/archive_text_channel"
	archiveapi "voice-platform/backend/internal/channel/archive_text_channel/api"
	archivepostgres "voice-platform/backend/internal/channel/archive_text_channel/postgres"
	"voice-platform/backend/internal/channel/close_voice_admission"
	closeapi "voice-platform/backend/internal/channel/close_voice_admission/api"
	closepostgres "voice-platform/backend/internal/channel/close_voice_admission/postgres"
	"voice-platform/backend/internal/channel/create_category"
	categoryapi "voice-platform/backend/internal/channel/create_category/api"
	categorypostgres "voice-platform/backend/internal/channel/create_category/postgres"
	"voice-platform/backend/internal/channel/create_channel"
	channelapi "voice-platform/backend/internal/channel/create_channel/api"
	channelpostgres "voice-platform/backend/internal/channel/create_channel/postgres"
	"voice-platform/backend/internal/channel/delete_empty_category"
	deletecategoryapi "voice-platform/backend/internal/channel/delete_empty_category/api"
	deletecategorypostgres "voice-platform/backend/internal/channel/delete_empty_category/postgres"
	"voice-platform/backend/internal/channel/list_topology"
	listapi "voice-platform/backend/internal/channel/list_topology/api"
	listpostgres "voice-platform/backend/internal/channel/list_topology/postgres"
	"voice-platform/backend/internal/channel/move_channel"
	moveapi "voice-platform/backend/internal/channel/move_channel/api"
	movepostgres "voice-platform/backend/internal/channel/move_channel/postgres"
	"voice-platform/backend/internal/channel/rename_category"
	renameapi "voice-platform/backend/internal/channel/rename_category/api"
	renamepostgres "voice-platform/backend/internal/channel/rename_category/postgres"
	"voice-platform/backend/internal/channel/rename_channel"
	renamechannelapi "voice-platform/backend/internal/channel/rename_channel/api"
	renamechannelpostgres "voice-platform/backend/internal/channel/rename_channel/postgres"
	"voice-platform/backend/internal/channel/reorder_categories"
	reorderapi "voice-platform/backend/internal/channel/reorder_categories/api"
	reorderpostgres "voice-platform/backend/internal/channel/reorder_categories/postgres"
	"voice-platform/backend/internal/channel/reorder_channels"
	channelreorderapi "voice-platform/backend/internal/channel/reorder_channels/api"
	channelreorderpostgres "voice-platform/backend/internal/channel/reorder_channels/postgres"
	topologycommandapi "voice-platform/backend/internal/channel/topology_command/api"
	topologycommandpostgres "voice-platform/backend/internal/channel/topology_command/postgres"
	"voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
	textcursorapi "voice-platform/backend/internal/chat/advance_text_channel_read_cursor/api"
	textcursorpostgres "voice-platform/backend/internal/chat/advance_text_channel_read_cursor/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureChannelRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub) {
	topologyService := listtopology.New(listpostgres.New(listpostgres.NewPoolDatabase(database)))
	topologyHandler := sessionapi.Require(sessions)(listapi.NewHandler(topologyService))
	textCursor := advancetextchannelreadcursor.New(textcursorpostgres.New(textcursorpostgres.NewPoolDatabase(database)))
	textCursorHandler := sessionapi.Require(sessions)(textcursorapi.NewHandler(textCursor))
	categoryService := createcategory.New(categorypostgres.New(categorypostgres.NewPoolDatabase(database)))
	categoryHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(categoryapi.NewHandler(categoryService)))
	channelService := createchannel.New(channelpostgres.New(channelpostgres.NewPoolDatabase(database)))
	channelHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(channelapi.NewHandler(channelService)))
	categoryReorder := reordercategories.New(reorderpostgres.New(reorderpostgres.NewPoolDatabase(database)))
	reorderHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(reorderapi.NewHandler(categoryReorder)))
	categoryRename := renamecategory.New(renamepostgres.New(renamepostgres.NewPoolDatabase(database)))
	renameHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(renameapi.NewHandler(categoryRename)))
	channelRename := renamechannel.New(renamechannelpostgres.New(renamechannelpostgres.NewPoolDatabase(database)))
	channelRenameHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(renamechannelapi.NewHandler(channelRename)))
	categoryDelete := deleteemptycategory.New(deletecategorypostgres.New(deletecategorypostgres.NewPoolDatabase(database)))
	deleteHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(deletecategoryapi.NewHandler(categoryDelete)))
	channelMove := movechannel.New(movepostgres.New(movepostgres.NewPoolDatabase(database)))
	moveHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(moveapi.NewHandler(channelMove)))
	channelReorder := reorderchannels.New(channelreorderpostgres.New(channelreorderpostgres.NewPoolDatabase(database)))
	channelReorderHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(channelreorderapi.NewHandler(channelReorder)))
	textArchive := archivetextchannel.New(archivepostgres.New(archivepostgres.NewPoolDatabase(database)))
	archiveHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(archiveapi.NewHandler(textArchive)))
	voiceAdmission := closevoiceadmission.New(closepostgres.New(closepostgres.NewPoolDatabase(database)))
	voiceAdmissionHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(closeapi.NewHandler(voiceAdmission)))
	commandReader := topologycommandpostgres.New(topologycommandpostgres.NewPoolDatabase(database))
	mux.Handle("GET /api/v1/channels", topologyHandler)
	mux.Handle("PUT /api/v1/channels/{channelID}/read-cursor", textCursorHandler)
	mux.Handle("GET /api/v1/topology-commands/{clientRequestID}", sessionapi.Require(sessions)(topologycommandapi.NewHandler(commandReader)))
	registerTopologyMutationRoutes(mux, events, topologyMutationHandlers{
		createCategory:      categoryHandler,
		reorderCategories:   reorderHandler,
		renameCategory:      renameHandler,
		deleteCategory:      deleteHandler,
		createChannel:       channelHandler,
		reorderChannels:     channelReorderHandler,
		renameChannel:       channelRenameHandler,
		moveChannel:         moveHandler,
		archiveTextChannel:  archiveHandler,
		closeVoiceAdmission: voiceAdmissionHandler,
	})
}
