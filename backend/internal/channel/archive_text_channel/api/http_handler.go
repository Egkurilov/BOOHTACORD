package archiveapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"voice-platform/backend/internal/channel/archive_text_channel"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Archiver interface {
	Archive(context.Context, archivetextchannel.Input) (archivetextchannel.Result, error)
}

func NewHandler(archiver Archiver) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodDelete {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось архивировать канал")
			return
		}
		var body struct {
			ExpectedRevision int64 `json:"expected_revision"`
			ConfirmArchive   *bool `json:"confirm_archive"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || body.ConfirmArchive == nil || !*body.ConfirmArchive {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Требуется явное подтверждение архивации")
			return
		}
		result, err := archiver.Archive(request.Context(), archivetextchannel.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), ExpectedRevision: body.ExpectedRevision, ConfirmArchive: *body.ConfirmArchive})
		if errors.Is(err, archivetextchannel.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Требуется явное подтверждение архивации")
			return
		}
		if errors.Is(err, archivetextchannel.ErrRevisionConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Конфликт ревизии или канал нельзя архивировать; обновите состояние")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось архивировать канал")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			ID       string `json:"id"`
			Revision int64  `json:"revision"`
		}{result.ID, result.Revision})
	})
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
