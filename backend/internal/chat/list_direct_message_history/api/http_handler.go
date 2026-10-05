package listdirectmessagehistoryapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listdirectmessagehistory.Input) (listdirectmessagehistory.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные сообщения")
			return
		}
		limit := 50
		if value := request.URL.Query().Get("limit"); value != "" {
			parsed, err := strconv.Atoi(value)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница личных сообщений")
				return
			}
			limit = parsed
		}
		result, err := lister.List(request.Context(), listdirectmessagehistory.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), Before: request.URL.Query().Get("before"), At: request.URL.Query().Get("at"), After: request.URL.Query().Get("after"), Limit: limit})
		if errors.Is(err, listdirectmessagehistory.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница личных сообщений")
			return
		}
		if errors.Is(err, listdirectmessagehistory.ErrDirectMessageUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Личный диалог недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить личные сообщения")
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
	ID              string                                `json:"id"`
	DirectMessageID string                                `json:"direct_message_id"`
	AuthorID        string                                `json:"author_id"`
	ClientMessageID string                                `json:"client_message_id"`
	Body            string                                `json:"body"`
	ReplyToID       string                                `json:"reply_to_id,omitempty"`
	CreatedAt       time.Time                             `json:"created_at"`
	EditedAt        *time.Time                            `json:"edited_at,omitempty"`
	Revision        int                                   `json:"revision"`
	Deleted         bool                                  `json:"deleted"`
	ReplyPreview    *replyPreview                         `json:"reply_preview,omitempty"`
	Attachments     []listdirectmessagehistory.Attachment `json:"attachments"`
	MentionUserIDs  []string                              `json:"mention_user_ids"`
}

type replyPreview struct {
	ID       string `json:"id"`
	AuthorID string `json:"author_id"`
	Body     string `json:"body"`
	Deleted  bool   `json:"deleted"`
}

func messages(source []listdirectmessagehistory.Message) []message {
	result := make([]message, 0, len(source))
	for _, value := range source {
		var preview *replyPreview
		if value.ReplyPreview != nil {
			preview = &replyPreview{ID: value.ReplyPreview.ID, AuthorID: value.ReplyPreview.AuthorID, Body: value.ReplyPreview.Body, Deleted: value.ReplyPreview.Deleted}
		}
		attachments := value.Attachments
		if value.Deleted || attachments == nil {
			attachments = []listdirectmessagehistory.Attachment{}
		}
		mentions := value.MentionUserIDs
		if value.Deleted || mentions == nil {
			mentions = []string{}
		}
		result = append(result, message{ID: value.ID, DirectMessageID: value.DirectMessageID, AuthorID: value.AuthorID, ClientMessageID: value.ClientMessageID, Body: value.Body, ReplyToID: value.ReplyToID, CreatedAt: value.CreatedAt, EditedAt: value.EditedAt, Revision: value.Revision, Deleted: value.Deleted, ReplyPreview: preview, Attachments: attachments, MentionUserIDs: mentions})
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
