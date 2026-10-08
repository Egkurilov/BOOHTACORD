package listmessagereactionsapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	list "voice-platform/backend/internal/chat/list_message_reactions"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Lister interface {
	List(context.Context, list.Input) ([]list.Reaction, error)
}

func NewHandler(service Lister, direct bool) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, 403, "FORBIDDEN")
			return
		}
		query := r.URL.Query()
		values := query["message_ids"]
		if len(values) != 1 || values[0] == "" || len(values[0]) > 3700 {
			writeError(w, r, 400, "VALIDATION_FAILED")
			return
		}
		in := list.Input{ActorID: principal.AccountID, ConversationID: r.PathValue("channelID"), MessageIDs: strings.Split(values[0], ","), Direct: direct}
		if direct {
			in.ConversationID = r.PathValue("directMessageID")
		}
		reactions, err := service.List(r.Context(), in)
		if errors.Is(err, list.ErrInvalidInput) {
			writeError(w, r, 400, "VALIDATION_FAILED")
			return
		}
		if errors.Is(err, list.ErrUnavailable) {
			writeError(w, r, 404, "NOT_FOUND")
			return
		}
		if err != nil {
			writeError(w, r, 500, "INTERNAL")
			return
		}
		if reactions == nil {
			reactions = []list.Reaction{}
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		json.NewEncoder(w).Encode(map[string]any{"reactions": reactions, "can_pin": !direct && principal.Role == "ADMINISTRATOR"})
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось получить реакции", "request_id": requestid.From(r.Context())}})
}
