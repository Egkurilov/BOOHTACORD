package deletedirectmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Deleter interface {
	Delete(context.Context, deletedirectmessage.Input) (deletedirectmessage.Result, error)
}

func NewHandler(deleter Deleter) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить личное сообщение")
			return
		}
		_, err := deleter.Delete(request.Context(), deletedirectmessage.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: request.PathValue("messageID")})
		if errors.Is(err, deletedirectmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор личного сообщения")
			return
		}
		if errors.Is(err, deletedirectmessage.ErrDeleteDenied) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Личное сообщение недоступно")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить личное сообщение")
			return
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
