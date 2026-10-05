package ownsessionapi

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"github.com/google/uuid"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	ownsessions "voice-platform/backend/internal/identity/list_own_sessions"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Store interface {
	Read(context.Context, string, [sha256.Size]byte, string) (ownsessions.Page, error)
}

func New(store Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			fail(w, r, 401, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		cursor := r.URL.Query().Get("cursor")
		if cursor != "" {
			if _, err := uuid.Parse(cursor); err != nil {
				fail(w, r, 400, "VALIDATION_FAILED", "Некорректная страница сеансов")
				return
			}
		}
		page, err := store.Read(r.Context(), principal.AccountID, principal.SessionDigest, cursor)
		if err != nil {
			fail(w, r, 500, "INTERNAL", "Не удалось загрузить сеансы")
			return
		}
		_ = json.NewEncoder(w).Encode(page)
	})
}
func fail(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(r.Context()),
	}})
}
