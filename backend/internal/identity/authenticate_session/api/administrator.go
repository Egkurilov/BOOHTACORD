package sessionapi

import (
	"encoding/json"
	"net/http"

	"voice-platform/backend/internal/security/request_id"
)

func RequireAdministrator(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := PrincipalFrom(request.Context())
		if !ok {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		if principal.Role != "ADMINISTRATOR" {
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			writer.WriteHeader(http.StatusForbidden)
			_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
				"code":       "FORBIDDEN",
				"message":    "Недостаточно прав",
				"request_id": requestid.From(request.Context()),
			}})
			return
		}
		next.ServeHTTP(writer, request)
	})
}
