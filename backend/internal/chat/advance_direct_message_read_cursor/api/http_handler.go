package advancedirectmessagereadcursorapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Advancer interface {
	Advance(context.Context, advancedirectmessagereadcursor.Input) (advancedirectmessagereadcursor.Result, error)
}

func NewHandler(advancer Advancer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось обновить курсор личного диалога")
			return
		}
		var body struct {
			MessageID string `json:"message_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный курсор личного диалога")
			return
		}
		result, err := advancer.Advance(request.Context(), advancedirectmessagereadcursor.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: body.MessageID})
		if errors.Is(err, advancedirectmessagereadcursor.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный курсор личного диалога")
			return
		}
		if errors.Is(err, advancedirectmessagereadcursor.ErrDirectMessageUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Личный диалог недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось обновить курсор личного диалога")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{DirectMessageID: request.PathValue("directMessageID"), MessageID: result.MessageID, MessageCreatedAt: result.MessageCreatedAt})
	})
}

type response struct {
	DirectMessageID  string    `json:"direct_message_id"`
	MessageID        string    `json:"message_id"`
	MessageCreatedAt time.Time `json:"message_created_at"`
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
