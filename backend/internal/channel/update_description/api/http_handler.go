package descriptionapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"voice-platform/backend/internal/channel/update_description"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Updater interface {
	Update(context.Context, updatedescription.Input) (updatedescription.Result, error)
}

func NewHandler(updater Updater) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPatch {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить описание канала")
			return
		}
		var body struct {
			Description      *string `json:"description"`
			ExpectedRevision int64   `json:"expected_revision"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || body.Description == nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное описание канала или ревизия")
			return
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный JSON")
			return
		}
		result, err := updater.Update(request.Context(), updatedescription.Input{
			ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), Description: *body.Description, ExpectedRevision: body.ExpectedRevision,
		})
		switch {
		case errors.Is(err, updatedescription.ErrInvalidInput):
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное описание канала или ревизия")
		case errors.Is(err, updatedescription.ErrRevisionConflict):
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Конфликт ревизии; обновите состояние и повторите действие")
		case err != nil:
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить описание канала")
		default:
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			_ = json.NewEncoder(writer).Encode(struct {
				ID          string `json:"id"`
				Description string `json:"description"`
				Revision    int64  `json:"revision"`
			}{result.ID, result.Description, result.Revision})
		}
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(request.Context()),
	}})
}
