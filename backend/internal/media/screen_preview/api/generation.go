package screenpreviewapi

import (
	"encoding/json"
	"net/http"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func (handler *Handler) begin(writer http.ResponseWriter, request *http.Request) {
	who, ok := principal(request)
	if !ok {
		writeFailure(writer, request, screenpreview.ErrUnavailable)
		return
	}
	generation, err := handler.operations.Begin(request.Context(), who, request.PathValue("leaseID"))
	if err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(writer).Encode(generation)
}
