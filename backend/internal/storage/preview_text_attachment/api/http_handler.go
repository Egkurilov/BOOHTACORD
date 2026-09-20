package previewtextattachmentapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
	previewtextattachment "voice-platform/backend/internal/storage/preview_text_attachment"
)

type Renderer interface {
	Render(context.Context, downloadtextattachment.Input) ([]byte, error)
}

func NewHandler(renderer Renderer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось открыть предпросмотр вложения")
			return
		}
		rendered, err := renderer.Render(request.Context(), downloadtextattachment.Input{
			ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), AttachmentID: request.PathValue("attachmentID"),
		})
		if errors.Is(err, downloadtextattachment.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор вложения")
			return
		}
		if errors.Is(err, downloadtextattachment.ErrAttachmentUnavailable) || errors.Is(err, previewtextattachment.ErrPreviewUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Предпросмотр вложения недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось открыть предпросмотр вложения")
			return
		}
		writer.Header().Set("Content-Type", "image/png")
		writer.Header().Set("Content-Length", strconv.Itoa(len(rendered)))
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		_, _ = writer.Write(rendered)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(request.Context()),
	}})
}
