package channelsroutes

import (
	"net/http"

	publishtopologyevent "voice-platform/backend/internal/channel/publish_topology_event"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type topologyMutationHandlers struct {
	memberCreateCategory http.Handler
	memberCreateChannel  http.Handler
	memberDeleteCategory http.Handler
	memberArchiveText    http.Handler
	memberCloseVoice     http.Handler
	createCategory       http.Handler
	reorderCategories    http.Handler
	renameCategory       http.Handler
	deleteCategory       http.Handler
	createChannel        http.Handler
	reorderChannels      http.Handler
	renameChannel        http.Handler
	moveChannel          http.Handler
	archiveTextChannel   http.Handler
	closeVoiceAdmission  http.Handler
}

func registerTopologyMutationRoutes(mux *http.ServeMux, events *eventhub.Hub, handlers topologyMutationHandlers) {
	mux.Handle("POST /api/v1/categories", publishtopologyevent.NewHandler(handlers.memberCreateCategory, events))
	mux.Handle("POST /api/v1/categories/{categoryID}/channels", publishtopologyevent.NewHandler(handlers.memberCreateChannel, events))
	mux.Handle("DELETE /api/v1/categories/{categoryID}", publishtopologyevent.NewHandler(handlers.memberDeleteCategory, events))
	mux.Handle("DELETE /api/v1/channels/{channelID}", publishtopologyevent.NewHandler(handlers.memberArchiveText, events))
	mux.Handle("POST /api/v1/voice-channels/{channelID}/close-admission", publishtopologyevent.NewHandler(handlers.memberCloseVoice, events))
	mux.Handle("POST /api/v1/admin/categories", publishtopologyevent.NewHandler(handlers.createCategory, events))
	mux.Handle("PUT /api/v1/admin/categories/order", publishtopologyevent.NewHandler(handlers.reorderCategories, events))
	mux.Handle("PATCH /api/v1/admin/categories/{categoryID}", publishtopologyevent.NewHandler(handlers.renameCategory, events))
	mux.Handle("DELETE /api/v1/admin/categories/{categoryID}", publishtopologyevent.NewHandler(handlers.deleteCategory, events))
	mux.Handle("POST /api/v1/admin/categories/{categoryID}/channels", publishtopologyevent.NewHandler(handlers.createChannel, events))
	mux.Handle("PUT /api/v1/admin/categories/{categoryID}/channels/order", publishtopologyevent.NewHandler(handlers.reorderChannels, events))
	mux.Handle("PATCH /api/v1/admin/channels/{channelID}", publishtopologyevent.NewHandler(handlers.renameChannel, events))
	mux.Handle("PATCH /api/v1/admin/channels/{channelID}/category", publishtopologyevent.NewHandler(handlers.moveChannel, events))
	mux.Handle("DELETE /api/v1/admin/channels/{channelID}", publishtopologyevent.NewHandler(handlers.archiveTextChannel, events))
	mux.Handle("POST /api/v1/admin/voice-channels/{channelID}/close-admission", publishtopologyevent.NewHandler(handlers.closeVoiceAdmission, events))
}
