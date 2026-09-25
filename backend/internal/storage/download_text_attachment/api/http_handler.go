package downloadtextattachmentapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strconv"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

type Downloader interface {
	Open(context.Context, downloadtextattachment.Input) (downloadtextattachment.Opened, error)
}

func NewHandler(downloader Downloader) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось скачать вложение")
			return
		}
		opened, err := downloader.Open(request.Context(), downloadtextattachment.Input{
			ActorID:      principal.AccountID,
			ChannelID:    request.PathValue("channelID"),
			AttachmentID: request.PathValue("attachmentID"),
		})
		if errors.Is(err, downloadtextattachment.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор вложения")
			return
		}
		if errors.Is(err, downloadtextattachment.ErrAttachmentUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Вложение недоступно")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось скачать вложение")
			return
		}
		defer opened.Reader.Close()
		disposition := mime.FormatMediaType("attachment", map[string]string{"filename": opened.Metadata.OriginalName})
		if disposition == "" {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось скачать вложение")
			return
		}
		writer.Header().Set("Content-Type", "application/octet-stream")
		writer.Header().Set("Content-Disposition", disposition)
		writer.Header().Set("Content-Length", strconv.FormatInt(opened.Metadata.SizeBytes, 10))
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		_, _ = io.Copy(writer, opened.Reader)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       code,
		"message":    message,
		"request_id": requestid.From(request.Context()),
	}})
}
