package kickvoiceparticipantapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
)

type Kicker interface {
	Kick(context.Context, kickvoiceparticipant.Input) (kickvoiceparticipant.Result, error)
}

func NewHandler(kicker Kicker) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отключить участника от голоса")
			return
		}
		result, err := kicker.Kick(request.Context(), kickvoiceparticipant.Input{ActorID: principal.AccountID, TargetID: request.PathValue("accountID")})
		if errors.Is(err, kickvoiceparticipant.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор участника")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отключить участника от голоса")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			RevokedLeases int64 `json:"revoked_leases"`
		}{result.RevokedLeases})
	})
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
