package advancetextchannelreadcursorapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	advancetextchannelreadcursor "voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Advancer interface {
	Advance(context.Context, advancetextchannelreadcursor.Input) (advancetextchannelreadcursor.Result, error)
}

func NewHandler(advancer Advancer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось обновить курсор канала")
			return
		}
		var body struct {
			MessageID string `json:"message_id"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный курсор канала")
			return
		}
		result, err := advancer.Advance(request.Context(), advancetextchannelreadcursor.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), MessageID: body.MessageID})
		if errors.Is(err, advancetextchannelreadcursor.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный курсор канала")
			return
		}
		if errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Канал или сообщение недоступны")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось обновить курсор канала")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{ChannelID: request.PathValue("channelID"), MessageID: result.MessageID, MessageCreatedAt: result.MessageCreatedAt})
	})
}

type response struct {
	ChannelID        string    `json:"channel_id"`
	MessageID        string    `json:"message_id"`
	MessageCreatedAt time.Time `json:"message_created_at"`
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
