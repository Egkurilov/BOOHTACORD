package changetextpinapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	action "voice-platform/backend/internal/chat/change_text_pin"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Changer interface {
	Set(context.Context, action.Input) (action.Result, error)
}

func NewHandler(service Changer) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok || principal.Role != "ADMINISTRATOR" {
			writeError(w, r, 403, "FORBIDDEN")
			return
		}
		if r.Method != http.MethodPut && r.Method != http.MethodDelete {
			writeError(w, r, 405, "METHOD_NOT_ALLOWED")
			return
		}
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1))
		if err != nil || len(body) != 0 {
			writeError(w, r, 400, "VALIDATION_FAILED")
			return
		}
		in := action.Input{ActorID: principal.AccountID, ChannelID: r.PathValue("channelID"), MessageID: r.PathValue("messageID"), Present: r.Method == http.MethodPut}
		_, err = service.Set(r.Context(), in)
		if errors.Is(err, action.ErrInvalidInput) {
			writeError(w, r, 400, "VALIDATION_FAILED")
			return
		}
		if errors.Is(err, action.ErrUnavailable) {
			writeError(w, r, 404, "NOT_FOUND")
			return
		}
		if err != nil {
			writeError(w, r, 500, "INTERNAL")
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": "Не удалось обновить состояние сообщения", "request_id": requestid.From(r.Context())}})
}
