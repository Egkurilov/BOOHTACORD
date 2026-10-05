package inspectreadiness

import (
	"encoding/json"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func Handler(service *Service) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			http.Error(w, "Unauthorized", 401)
			return
		}
		if principal.Role != "ADMINISTRATOR" {
			http.Error(w, "Forbidden", 403)
			return
		}
		result := service.Inspect(r.Context())
		w.Header().Set("Content-Type", "application/json")
		if result.Status != "ready" {
			w.WriteHeader(http.StatusServiceUnavailable)
		}
		_ = json.NewEncoder(w).Encode(result)
	})
}
