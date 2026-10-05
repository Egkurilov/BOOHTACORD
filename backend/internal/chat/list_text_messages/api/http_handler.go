package listtextmessagesapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"
	messagekind "voice-platform/backend/internal/chat/message_kind"

	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listtextmessages.Input) (listtextmessages.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		limit := 50
		if value := request.URL.Query().Get("limit"); value != "" {
			parsed, err := strconv.Atoi(value)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница сообщений")
				return
			}
			limit = parsed
		}
		result, err := lister.List(request.Context(), listtextmessages.Input{ChannelID: request.PathValue("channelID"), Before: request.URL.Query().Get("before"), At: request.URL.Query().Get("at"), After: request.URL.Query().Get("after"), Limit: limit})
		if errors.Is(err, listtextmessages.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница сообщений")
			return
		}
		if errors.Is(err, listtextmessages.ErrChannelUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Текстовый канал недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить сообщения")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{Messages: messages(result.Messages), NextCursor: result.NextCursor})
	})
}

type response struct {
	Messages   []message `json:"messages"`
	NextCursor string    `json:"next_cursor,omitempty"`
}
type message struct {
	Kind            string       `json:"kind"`
	ID              string       `json:"id"`
	ChannelID       string       `json:"channel_id"`
	AuthorID        string       `json:"author_id"`
	ClientMessageID string       `json:"client_message_id"`
	Body            string       `json:"body"`
	ReplyToID       string       `json:"reply_to_id,omitempty"`
	CreatedAt       time.Time    `json:"created_at"`
	EditedAt        *time.Time   `json:"edited_at,omitempty"`
	Revision        int          `json:"revision"`
	Deleted         bool         `json:"deleted"`
	Attachments     []attachment `json:"attachments"`
	MentionUserIDs  []string     `json:"mention_user_ids"`
}

type attachment struct {
	ID           string `json:"id"`
	OriginalName string `json:"original_name"`
	SizeBytes    int64  `json:"byte_size"`
}

func messages(source []listtextmessages.Message) []message {
	result := make([]message, 0, len(source))
	for _, value := range source {
		mentions := value.MentionUserIDs
		if value.Deleted || mentions == nil {
			mentions = []string{}
		}
		result = append(result, message{Kind: messagekind.OrUser(value.Kind), ID: value.ID, ChannelID: value.ChannelID, AuthorID: value.AuthorID, ClientMessageID: value.ClientMessageID, Body: value.Body, ReplyToID: value.ReplyToID, CreatedAt: value.CreatedAt, EditedAt: value.EditedAt, Revision: value.Revision, Deleted: value.Deleted, Attachments: attachments(value.Attachments), MentionUserIDs: mentions})
	}
	return result
}

func attachments(source []listtextmessages.Attachment) []attachment {
	result := make([]attachment, 0, len(source))
	for _, value := range source {
		result = append(result, attachment{ID: value.ID, OriginalName: value.OriginalName, SizeBytes: value.SizeBytes})
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
