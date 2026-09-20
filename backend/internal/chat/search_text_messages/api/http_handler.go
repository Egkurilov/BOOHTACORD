package searchtextmessagesapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
	"voice-platform/backend/internal/security/request_id"
)

type Searcher interface {
	Search(context.Context, searchtextmessages.Input) (searchtextmessages.Result, error)
}

func NewHandler(searcher Searcher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
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
		result, err := searcher.Search(request.Context(), searchtextmessages.Input{ChannelID: request.PathValue("channelID"), Query: query, Before: request.URL.Query().Get("before"), Limit: limit})
		if errors.Is(err, searchtextmessages.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный поисковый запрос")
			return
		}
		if errors.Is(err, searchtextmessages.ErrChannelUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Текстовый канал недоступен")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить поиск сообщений")
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
	ID        string     `json:"id"`
	ChannelID string     `json:"channel_id"`
	AuthorID  string     `json:"author_id"`
	Body      string     `json:"body"`
	CreatedAt time.Time  `json:"created_at"`
	EditedAt  *time.Time `json:"edited_at,omitempty"`
	Revision  int        `json:"revision"`
}

func messages(source []searchtextmessages.Message) []message {
	result := make([]message, 0, len(source))
	for _, value := range source {
		result = append(result, message{ID: value.ID, ChannelID: value.ChannelID, AuthorID: value.AuthorID, Body: value.Body, CreatedAt: value.CreatedAt, EditedAt: value.EditedAt, Revision: value.Revision})
	}
	return result
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
