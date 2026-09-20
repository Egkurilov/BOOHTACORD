package moveapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"voice-platform/backend/internal/channel/move_channel"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Mover interface {
	Move(context.Context, movechannel.Input) (movechannel.Result, error)
}

func NewHandler(mover Mover) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPatch {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось переместить канал")
			return
		}
		var body struct {
			CategoryID       string `json:"category_id"`
			ExpectedRevision int64  `json:"expected_revision"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное перемещение канала")
			return
		}
		result, err := mover.Move(request.Context(), movechannel.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), CategoryID: body.CategoryID, ExpectedRevision: body.ExpectedRevision})
		if errors.Is(err, movechannel.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректное перемещение канала")
			return
		}
		if errors.Is(err, movechannel.ErrRevisionConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Конфликт ревизии; обновите состояние и повторите действие")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось переместить канал")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			ID         string `json:"id"`
			CategoryID string `json:"category_id"`
			Position   int    `json:"position"`
			Revision   int64  `json:"revision"`
		}{result.ID, result.CategoryID, result.Position, result.Revision})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
