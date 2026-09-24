package searchmessagesapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Searcher interface {
	Search(context.Context, searchmessages.Input) (searchmessages.Result, error)
}

func NewHandler(searcher Searcher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить поиск сообщений")
			return
		}
		query, valid := single(request, "query")
		channelID, channelOK := single(request, "channel_id")
		directMessageID, directMessageOK := single(request, "direct_message_id")
		before, beforeOK := single(request, "before")
		limitValue, limitOK := single(request, "limit")
		if !valid || !channelOK || !directMessageOK || !beforeOK || !limitOK || query == "" || (channelID != "" && directMessageID != "") {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный поисковый запрос")
			return
		}
		limit := 50
		if limitValue != "" {
			parsed, err := strconv.Atoi(limitValue)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница поиска")
				return
			}
			limit = parsed
		}
		result, err := searcher.Search(request.Context(), searchmessages.Input{ActorID: principal.AccountID, ChannelID: channelID, DirectMessageID: directMessageID, Query: query, Before: before, Limit: limit})
		if errors.Is(err, searchmessages.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный поисковый запрос")
			return
		}
		if errors.Is(err, searchmessages.ErrConversationUnavailable) {
			writeError(writer, request, http.StatusNotFound, "NOT_FOUND", "Беседа недоступна")
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
	ID              string     `json:"id"`
	Kind            string     `json:"kind"`
	ChannelID       string     `json:"channel_id,omitempty"`
	DirectMessageID string     `json:"direct_message_id,omitempty"`
	AuthorID        string     `json:"author_id"`
	Body            string     `json:"body"`
	CreatedAt       time.Time  `json:"created_at"`
	EditedAt        *time.Time `json:"edited_at,omitempty"`
	Revision        int        `json:"revision"`
}

func messages(source []searchmessages.Message) []message {
	result := make([]message, 0, len(source))
	for _, value := range source {
		result = append(result, message{ID: value.ID, Kind: value.Kind, ChannelID: value.ChannelID, DirectMessageID: value.DirectMessageID, AuthorID: value.AuthorID, Body: value.Body, CreatedAt: value.CreatedAt, EditedAt: value.EditedAt, Revision: value.Revision})
	}
	return result
}

func single(request *http.Request, name string) (string, bool) {
	values, ok := request.URL.Query()[name]
	if !ok {
		return "", true
	}
	if len(values) != 1 {
		return "", false
	}
	return values[0], true
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
