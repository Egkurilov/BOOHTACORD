package listtopologyapi

import (
	"context"
	"encoding/json"
	"net/http"

	listtopology "voice-platform/backend/internal/channel/list_topology"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listtopology.Input) (listtopology.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request)
			return
		}
		result, err := lister.List(request.Context(), listtopology.Input{ActorID: principal.AccountID})
		if err != nil {
			writeError(writer, request)
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{Revision: result.Revision, Categories: categories(result.Categories)})
	})
}

type response struct {
	Revision   int64      `json:"revision"`
	Categories []category `json:"categories"`
}
type category struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Position int       `json:"position"`
	Channels []channel `json:"channels"`
}
type channel struct {
	ID                   string `json:"id"`
	Name                 string `json:"name"`
	Description          string `json:"description,omitempty"`
	Kind                 string `json:"kind"`
	Position             int    `json:"position"`
	AdmissionClosed      bool   `json:"admission_closed"`
	UnreadCount          *int64 `json:"unread_count,omitempty"`
	MentionCount         *int64 `json:"mention_count,omitempty"`
	FirstUnreadMessageID string `json:"first_unread_message_id,omitempty"`
}

func categories(source []listtopology.Category) []category {
	result := make([]category, 0, len(source))
	for _, item := range source {
		current := category{ID: item.ID, Name: item.Name, Position: item.Position, Channels: make([]channel, 0, len(item.Channels))}
		for _, item := range item.Channels {
			value := channel{ID: item.ID, Name: item.Name, Description: item.Description, Kind: item.Kind, Position: item.Position, AdmissionClosed: item.AdmissionClosed}
			if item.Kind == "TEXT" {
				value.UnreadCount = &item.UnreadCount
				value.MentionCount = &item.MentionCount
				value.FirstUnreadMessageID = item.FirstUnreadMessageID
			}
			current.Channels = append(current.Channels, value)
		}
		result = append(result, current)
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusInternalServerError)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": "INTERNAL", "message": "Не удалось загрузить каналы", "request_id": requestid.From(request.Context())}})
}
