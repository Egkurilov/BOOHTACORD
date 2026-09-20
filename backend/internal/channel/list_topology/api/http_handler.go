package listtopologyapi

import (
	"context"
	"encoding/json"
	"net/http"

	listtopology "voice-platform/backend/internal/channel/list_topology"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context) (listtopology.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		result, err := lister.List(request.Context())
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
	ID              string `json:"id"`
	Name            string `json:"name"`
	Kind            string `json:"kind"`
	Position        int    `json:"position"`
	AdmissionClosed bool   `json:"admission_closed"`
}

func categories(source []listtopology.Category) []category {
	result := make([]category, 0, len(source))
	for _, item := range source {
		current := category{ID: item.ID, Name: item.Name, Position: item.Position, Channels: make([]channel, 0, len(item.Channels))}
		for _, item := range item.Channels {
			current.Channels = append(current.Channels, channel{ID: item.ID, Name: item.Name, Kind: item.Kind, Position: item.Position, AdmissionClosed: item.AdmissionClosed})
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
