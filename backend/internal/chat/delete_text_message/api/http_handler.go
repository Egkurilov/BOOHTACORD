package deletetextmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Deleter interface {
	Delete(context.Context, deletetextmessage.Input) (deletetextmessage.Result, error)
}

func NewHandler(deleter Deleter) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить сообщение")
			return
		}
		_, err := deleter.Delete(request.Context(), deletetextmessage.Input{ActorID: principal.AccountID, ActorRole: principal.Role, ChannelID: request.PathValue("channelID"), MessageID: request.PathValue("messageID")})
		if errors.Is(err, deletetextmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор сообщения")
			return
		}
		if errors.Is(err, deletetextmessage.ErrDeleteDenied) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Сообщение недоступно")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось удалить сообщение")
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
