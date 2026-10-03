package permissionsapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Resolver interface {
	Resolve(context.Context, effectivepermissions.Principal) (effectivepermissions.Snapshot, error)
}

func NewHandler(resolver Resolver) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось определить разрешения")
			return
		}
		snapshot, err := resolver.Resolve(request.Context(), effectivepermissions.Principal{AccountID: principal.AccountID, Role: principal.Role})
		if errors.Is(err, effectivepermissions.ErrPermissionsUnavailable) {
			writeError(writer, request, http.StatusServiceUnavailable, "PERMISSIONS_UNAVAILABLE", "Разрешения временно недоступны")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось определить разрешения")
			return
		}
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(map[string]any{
			"account_id": snapshot.AccountID, "role": snapshot.Role,
			"permissions_revision": snapshot.Revision, "permissions": snapshot.Permissions,
		})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
