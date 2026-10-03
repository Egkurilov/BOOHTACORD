package permissionguard

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"

	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/security/request_id"
)

type Resolver interface {
	Resolve(context.Context, effectivepermissions.Principal) (effectivepermissions.Snapshot, error)
}

func Require(resolver Resolver, permission permissionregistry.Permission) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if !allowed(writer, request, resolver, permission) {
				return
			}
			next.ServeHTTP(writer, request)
		})
	}
}

func RequireChannelCreate(resolver Resolver) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			body, err := io.ReadAll(http.MaxBytesReader(writer, request.Body, 8<<10))
			request.Body = io.NopCloser(bytes.NewReader(body))
			if err != nil {
				next.ServeHTTP(writer, request)
				return
			}
			var probe struct {
				Kind string `json:"kind"`
			}
			if json.Unmarshal(body, &probe) != nil {
				next.ServeHTTP(writer, request)
				return
			}
			permission := permissionregistry.ChannelTextCreate
			if probe.Kind == "VOICE" {
				permission = permissionregistry.ChannelVoiceCreate
			} else if probe.Kind != "TEXT" {
				next.ServeHTTP(writer, request)
				return
			}
			if !allowed(writer, request, resolver, permission) {
				return
			}
			next.ServeHTTP(writer, request)
		})
	}
}

func allowed(writer http.ResponseWriter, request *http.Request, resolver Resolver, permission permissionregistry.Permission) bool {
	principal, ok := sessionapi.PrincipalFrom(request.Context())
	if !ok {
		writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось проверить разрешение")
		return false
	}
	snapshot, err := resolver.Resolve(request.Context(), effectivepermissions.Principal{AccountID: principal.AccountID, Role: principal.Role})
	if err != nil {
		writeError(writer, request, http.StatusServiceUnavailable, "PERMISSIONS_UNAVAILABLE", "Разрешения временно недоступны")
		return false
	}
	if !snapshot.Permissions[permission] {
		writeError(writer, request, http.StatusForbidden, "PERMISSION_DENIED", "Действие не разрешено")
		return false
	}
	return true
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
