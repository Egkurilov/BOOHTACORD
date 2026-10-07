package screenpreviewapi

import (
	"errors"
	"io"
	"mime"
	"net/http"
	"strconv"
	"strings"

	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func (handler *Handler) upload(writer http.ResponseWriter, request *http.Request) {
	mediaType, parameters, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || !strings.EqualFold(mediaType, "image/jpeg") || len(parameters) != 0 {
		writer.WriteHeader(http.StatusUnsupportedMediaType)
		return
	}
	revision, err := strconv.ParseUint(request.Header.Get("X-Screen-Preview-Revision"), 10, 63)
	if err != nil || revision == 0 {
		writeBadRequest(writer, request)
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(writer, request.Body, screenpreview.MaxJPEGBytes))
	if err != nil {
		var oversized *http.MaxBytesError
		if errors.As(err, &oversized) {
			writer.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		writeBadRequest(writer, request)
		return
	}
	who, ok := principal(request)
	if !ok {
		writeFailure(writer, request, screenpreview.ErrUnavailable)
		return
	}
	err = handler.operations.Upload(request.Context(), who, request.PathValue("leaseID"), request.PathValue("generationID"), revision, body)
	if err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.Header().Set("X-Screen-Preview-Revision", strconv.FormatUint(revision, 10))
	writer.WriteHeader(http.StatusNoContent)
}
