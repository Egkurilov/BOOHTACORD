package deliveryapi

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"net/http"
	delivery "voice-platform/backend/internal/chat/lookup_message_delivery"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Store interface {
	Lookup(context.Context, delivery.Input) (*string, error)
}

func New(store Store, direct bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			failure(w, r, 401, "UNAUTHENTICATED")
			return
		}
		conversation := r.PathValue("channelID")
		if direct {
			conversation = r.PathValue("directMessageID")
		}
		client := r.PathValue("clientMessageID")
		if uuid.Validate(conversation) != nil || uuid.Validate(client) != nil {
			failure(w, r, 400, "VALIDATION_FAILED")
			return
		}
		id, err := store.Lookup(r.Context(), delivery.Input{ActorID: principal.AccountID, ConversationID: conversation, ClientMessageID: client, Direct: direct})
		if errors.Is(err, delivery.ErrUnavailable) {
			failure(w, r, 404, "NOT_FOUND")
			return
		}
		if err != nil {
			failure(w, r, 500, "INTERNAL")
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(w).Encode(struct {
			ID        *string `json:"message_id"`
			AccountID string  `json:"account_id"`
		}{id, principal.AccountID})
	})
}
func failure(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось проверить доставку.", "request_id": requestid.From(r.Context())}})
}
