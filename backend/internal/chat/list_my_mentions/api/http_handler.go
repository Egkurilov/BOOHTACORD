package listmymentionsapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	listmymentions "voice-platform/backend/internal/chat/list_my_mentions"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, listmymentions.Input) (listmymentions.Result, error)
}

func NewHandler(lister Lister) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить упоминания")
			return
		}
		before, valid := single(request, "before")
		limitValue, limitOK := single(request, "limit")
		if !valid || !limitOK {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница упоминаний")
			return
		}
		limit := 50
		if limitValue != "" {
			parsed, err := strconv.Atoi(limitValue)
			if err != nil {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный лимит упоминаний")
				return
			}
			limit = parsed
		}
		result, err := lister.List(request.Context(), listmymentions.Input{ActorID: principal.AccountID, Before: before, Limit: limit})
		if errors.Is(err, listmymentions.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректная страница упоминаний")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось загрузить упоминания")
			return
		}
		writer.Header().Set("Cache-Control", "private, no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(response{Mentions: mentions(result.Mentions), NextCursor: result.NextCursor})
	})
}

type response struct {
	Mentions   []mention `json:"mentions"`
	NextCursor string    `json:"next_cursor,omitempty"`
}
type mention struct {
	Kind           string    `json:"kind"`
	MessageID      string    `json:"message_id"`
	ConversationID string    `json:"conversation_id"`
	AuthorID       string    `json:"author_id"`
	CreatedAt      time.Time `json:"created_at"`
}

func mentions(source []listmymentions.Mention) []mention {
	result := make([]mention, 0, len(source))
	for _, item := range source {
		result = append(result, mention{Kind: item.Kind, MessageID: item.ID, ConversationID: item.ConversationID, AuthorID: item.AuthorID, CreatedAt: item.CreatedAt})
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
