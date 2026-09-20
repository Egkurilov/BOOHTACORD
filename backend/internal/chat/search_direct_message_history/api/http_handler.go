package searchdirectmessagehistoryapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	searchdirectmessagehistory "voice-platform/backend/internal/chat/search_direct_message_history"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Searcher interface {
	Search(context.Context, searchdirectmessagehistory.Input) (searchdirectmessagehistory.Result, error)
}

func NewHandler(searcher Searcher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить поиск личных сообщений")
			return
		}
		query := request.URL.Query().Get("query")
		if query == "" {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный поисковый запрос")
			return
		}
		limit := 50
		if value := request.URL.Query().Get("limit"); value != "" {
			parsed, err := strconv.Atoi(value)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница поиска")
				return
			}
			limit = parsed
		}
		result, err := searcher.Search(request.Context(), searchdirectmessagehistory.Input{ActorID: principal.AccountID, DirectMessageID: request.PathValue("directMessageID"), Query: query, Before: request.URL.Query().Get("before"), Limit: limit})
		if errors.Is(err, searchdirectmessagehistory.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный поисковый запрос")
			return
		}
		if errors.Is(err, searchdirectmessagehistory.ErrDirectMessageUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Личный диалог недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить поиск личных сообщений")
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
	ID              string     `json:"id"`
	DirectMessageID string     `json:"direct_message_id"`
	AuthorID        string     `json:"author_id"`
	Body            string     `json:"body"`
	CreatedAt       time.Time  `json:"created_at"`
	EditedAt        *time.Time `json:"edited_at,omitempty"`
	Revision        int        `json:"revision"`
}

func messages(source []searchdirectmessagehistory.Message) []message {
	result := make([]message, 0, len(source))
	for _, value := range source {
		result = append(result, message{ID: value.ID, DirectMessageID: value.DirectMessageID, AuthorID: value.AuthorID, Body: value.Body, CreatedAt: value.CreatedAt, EditedAt: value.EditedAt, Revision: value.Revision})
	}
	return result
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
