package inspectvoiceclosure

import (
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func Handler(service Service) http.Handler {
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
		id := r.PathValue("channelID")
		if uuid.Validate(id) != nil {
			http.Error(w, "Not found", 404)
			return
		}
		result, err := service.Inspect(r.Context(), id)
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "Not found", 404)
			return
		}
		if err != nil {
			http.Error(w, "State unavailable", 503)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(result)
	})
}
