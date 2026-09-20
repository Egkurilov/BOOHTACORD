package createtextmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Creator interface {
	Create(context.Context, createtextmessage.Input) (createtextmessage.Result, error)
}

func NewHandler(creator Creator) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отправить сообщение")
			return
		}
		var body struct {
			ClientMessageID string   `json:"client_message_id"`
			Body            string   `json:"body"`
			ReplyToID       string   `json:"reply_to_id"`
			AttachmentIDs   []string `json:"attachment_ids"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 40<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные сообщения")
			return
		}
		result, err := creator.Create(request.Context(), createtextmessage.Input{ActorID: principal.AccountID, ChannelID: request.PathValue("channelID"), ClientMessageID: body.ClientMessageID, Body: body.Body, ReplyToID: body.ReplyToID, AttachmentIDs: body.AttachmentIDs})
		if errors.Is(err, createtextmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные сообщения")
			return
		}
		if errors.Is(err, createtextmessage.ErrChannelUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Текстовый канал или исходное сообщение недоступны")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось отправить сообщение")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		writer.WriteHeader(http.StatusCreated)
		response := messageResponse{ID: result.ID, ChannelID: result.ChannelID, AuthorID: result.AuthorID, ClientMessageID: result.ClientMessageID, Body: result.Body, Revision: result.Revision, CreatedAt: result.CreatedAt}
		if result.ReplyToID != "" {
			response.ReplyToID = &result.ReplyToID
		}
		_ = json.NewEncoder(writer).Encode(response)
	})
}

type messageResponse struct {
	ID              string    `json:"id"`
	ChannelID       string    `json:"channel_id"`
	AuthorID        string    `json:"author_id"`
	ClientMessageID string    `json:"client_message_id"`
	Body            string    `json:"body"`
	Revision        int       `json:"revision"`
	ReplyToID       *string   `json:"reply_to_id,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
