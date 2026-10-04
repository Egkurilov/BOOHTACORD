package guildsettingsapi

import (
	"encoding/json"
	"net/http"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Handler struct {
	Store    guildsettings.Store
	Observer *guildlifecycle.Observer
	Events   *eventhub.Hub
}

func (h Handler) Public(writer http.ResponseWriter, request *http.Request) {
	settings, err := h.Store.Read(request.Context())
	if err != nil {
		writeError(writer, request, 500, "INTERNAL")
		return
	}
	writer.Header().Set("Cache-Control", "no-store")
	writeJSON(writer, 200, struct {
		Name     string `json:"name"`
		Revision int64  `json:"revision"`
	}{settings.Name, settings.Revision})
}
func (h Handler) Read(writer http.ResponseWriter, request *http.Request) {
	settings, err := h.Store.Read(request.Context())
	if err != nil {
		writeError(writer, request, 500, "INTERNAL")
		return
	}
	writer.Header().Set("Cache-Control", "no-store")
	writeJSON(writer, 200, settings)
}
func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
