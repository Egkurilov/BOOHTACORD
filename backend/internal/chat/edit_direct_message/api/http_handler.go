package editdirectmessageapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Editor interface {
	Edit(context.Context, editdirectmessage.Input) (editdirectmessage.Result, error)
}

func NewHandler(editor Editor) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить личное сообщение")
			return
		}
		var body struct {
			Body             string   `json:"body"`
			ExpectedRevision int      `json:"expected_revision"`
			MentionUserIDs   []string `json:"mention_user_ids"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 40<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные личного сообщения")
			return
		}
		result, err := editor.Edit(request.Context(), editdirectmessage.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), MessageID: request.PathValue("messageID"), Body: body.Body, ExpectedRevision: body.ExpectedRevision, MentionUserIDs: body.MentionUserIDs})
		if errors.Is(err, editdirectmessage.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные личного сообщения")
			return
		}
		if errors.Is(err, editdirectmessage.ErrConflict) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Сообщение изменено, удалено или недоступно; обновите историю")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить личное сообщение")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{ID: result.ID, DirectMessageID: result.DirectMessageID, AuthorID: result.AuthorID, ClientMessageID: result.ClientMessageID, Body: result.Body, ReplyToID: result.ReplyToID, Revision: result.Revision, CreatedAt: result.CreatedAt, EditedAt: result.EditedAt, MentionUserIDs: nonNilMentions(result.MentionUserIDs)})
	})
}

type response struct {
	ID              string    `json:"id"`
	DirectMessageID string    `json:"direct_message_id"`
	AuthorID        string    `json:"author_id"`
	ClientMessageID string    `json:"client_message_id"`
	Body            string    `json:"body"`
	ReplyToID       string    `json:"reply_to_id,omitempty"`
	Revision        int       `json:"revision"`
	CreatedAt       time.Time `json:"created_at"`
	EditedAt        time.Time `json:"edited_at"`
	MentionUserIDs  []string  `json:"mention_user_ids"`
}

func nonNilMentions(ids []string) []string {
	if ids == nil {
		return []string{}
	}
	return ids
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
