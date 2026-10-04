package channelsroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	permissionguard "voice-platform/backend/internal/authorization/permission_guard"
	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	rolepolicypostgres "voice-platform/backend/internal/authorization/role_policy/postgres"
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
	"voice-platform/backend/internal/channel/update_description"
	descriptionapi "voice-platform/backend/internal/channel/update_description/api"
	descriptionpostgres "voice-platform/backend/internal/channel/update_description/postgres"
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
	categoryRawHandler := categoryapi.NewHandler(categoryService)
	categoryHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(categoryRawHandler))
	channelService := createchannel.New(channelpostgres.New(channelpostgres.NewPoolDatabase(database)))
	channelRawHandler := channelapi.NewHandler(channelService)
	channelHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(channelRawHandler))
	policyStore := rolepolicypostgres.New(rolepolicypostgres.NewPoolDatabase(database))
	permissionResolver := effectivepermissions.New(policyStore)
	memberCategoryHandler := sessionapi.Require(sessions)(permissionguard.Require(permissionResolver, permissionregistry.CategoryCreate)(categoryRawHandler))
	memberChannelHandler := sessionapi.Require(sessions)(permissionguard.RequireChannelCreate(permissionResolver)(channelRawHandler))
	categoryReorder := reordercategories.New(reorderpostgres.New(reorderpostgres.NewPoolDatabase(database)))
	reorderHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(reorderapi.NewHandler(categoryReorder)))
	categoryRename := renamecategory.New(renamepostgres.New(renamepostgres.NewPoolDatabase(database)))
	renameHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(renameapi.NewHandler(categoryRename)))
	channelRename := renamechannel.New(renamechannelpostgres.New(renamechannelpostgres.NewPoolDatabase(database)))
	channelRenameHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(renamechannelapi.NewHandler(channelRename)))
	channelDescription := updatedescription.New(descriptionpostgres.New(descriptionpostgres.NewPoolDatabase(database)))
	channelDescriptionHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(descriptionapi.NewHandler(channelDescription)))
	categoryDelete := deleteemptycategory.New(deletecategorypostgres.New(deletecategorypostgres.NewPoolDatabase(database)))
	deleteRawHandler := deletecategoryapi.NewHandler(categoryDelete)
	deleteHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(deleteRawHandler))
	channelMove := movechannel.New(movepostgres.New(movepostgres.NewPoolDatabase(database)))
	moveHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(moveapi.NewHandler(channelMove)))
	channelReorder := reorderchannels.New(channelreorderpostgres.New(channelreorderpostgres.NewPoolDatabase(database)))
	channelReorderHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(channelreorderapi.NewHandler(channelReorder)))
	textArchive := archivetextchannel.New(archivepostgres.New(archivepostgres.NewPoolDatabase(database)))
	archiveRawHandler := archiveapi.NewHandler(textArchive)
	archiveHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(archiveRawHandler))
	voiceAdmission := closevoiceadmission.New(closepostgres.New(closepostgres.NewPoolDatabase(database)))
	voiceAdmissionRawHandler := closeapi.NewHandler(voiceAdmission)
	voiceAdmissionHandler := sessionapi.Require(sessions)(sessionapi.RequireAdministrator(voiceAdmissionRawHandler))
	memberCategoryDelete := sessionapi.Require(sessions)(permissionguard.Require(permissionResolver, permissionregistry.CategoryDelete)(deleteRawHandler))
	memberTextArchive := sessionapi.Require(sessions)(permissionguard.Require(permissionResolver, permissionregistry.ChannelTextDelete)(archiveRawHandler))
	memberVoiceClose := sessionapi.Require(sessions)(permissionguard.Require(permissionResolver, permissionregistry.ChannelVoiceDelete)(voiceAdmissionRawHandler))
	commandReader := topologycommandpostgres.New(topologycommandpostgres.NewPoolDatabase(database))
	mux.Handle("GET /api/v1/channels", topologyHandler)
	mux.Handle("PUT /api/v1/channels/{channelID}/read-cursor", textCursorHandler)
	mux.Handle("GET /api/v1/topology-commands/{clientRequestID}", sessionapi.Require(sessions)(topologycommandapi.NewHandler(commandReader)))
	registerTopologyMutationRoutes(mux, events, topologyMutationHandlers{
		memberCreateCategory: memberCategoryHandler,
		memberCreateChannel:  memberChannelHandler,
		memberDeleteCategory: memberCategoryDelete,
		memberArchiveText:    memberTextArchive,
		memberCloseVoice:     memberVoiceClose,
		createCategory:       categoryHandler,
		reorderCategories:    reorderHandler,
		renameCategory:       renameHandler,
		deleteCategory:       deleteHandler,
		createChannel:        channelHandler,
		reorderChannels:      channelReorderHandler,
		renameChannel:        channelRenameHandler,
		updateDescription:    channelDescriptionHandler,
		moveChannel:          moveHandler,
		archiveTextChannel:   archiveHandler,
		closeVoiceAdmission:  voiceAdmissionHandler,
	})
}
