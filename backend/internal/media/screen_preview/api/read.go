package screenpreviewapi

import (
	"net/http"
	"strconv"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func (handler *Handler) read(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writer.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	if len(request.URL.RawQuery) > 24 {
		writeBadRequest(writer, request)
		return
	}
	var after uint64
	query := request.URL.Query()
	for key := range query {
		if key != "after_revision" {
			writeBadRequest(writer, request)
			return
		}
	}
	if raw := query.Get("after_revision"); raw != "" {
		value, err := strconv.ParseUint(raw, 10, 63)
		if err != nil {
			writeBadRequest(writer, request)
			return
		}
		after = value
	}
	who, ok := principal(request)
	if !ok {
		writeFailure(writer, request, screenpreview.ErrUnavailable)
		return
	}
	preview, err := handler.operations.Read(request.Context(), who, request.PathValue("leaseID"), request.PathValue("generationID"), after)
	if err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.Header().Set("Content-Type", "image/jpeg")
	writer.Header().Set("X-Screen-Preview-Revision", strconv.FormatUint(preview.Revision, 10))
	writer.Header().Set("Content-Length", strconv.Itoa(len(preview.JPEG)))
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write(preview.JPEG)
}

func (handler *Handler) invalidate(writer http.ResponseWriter, request *http.Request) {
	who, ok := principal(request)
	if !ok {
		writeFailure(writer, request, screenpreview.ErrUnavailable)
		return
	}
	if err := handler.operations.Invalidate(request.Context(), who, request.PathValue("leaseID"), request.PathValue("generationID")); err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.WriteHeader(http.StatusNoContent)
}
