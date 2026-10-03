package permissionsapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerReturnsCurrentEffectivePermissionsWithoutCaching(t *testing.T) {
	resolver := fakeResolver{snapshot: effectivepermissions.Snapshot{AccountID: "member-1", Role: "MEMBER", Revision: 7, Permissions: permissionregistry.MemberDefaults(7).Values()}}
	request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/permissions", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1", Role: "MEMBER"}))
	response := httptest.NewRecorder()
	NewHandler(resolver).ServeHTTP(response, request)
	var body map[string]any
	_ = json.Unmarshal(response.Body.Bytes(), &body)
	if response.Code != http.StatusOK || response.Header().Get("Cache-Control") != "no-store" || body["role"] != "MEMBER" || body["permissions_revision"] != float64(7) {
		t.Fatalf("response = %d %s %#v", response.Code, response.Body.String(), response.Header())
	}
}

type fakeResolver struct{ snapshot effectivepermissions.Snapshot }

func (resolver fakeResolver) Resolve(context.Context, effectivepermissions.Principal) (effectivepermissions.Snapshot, error) {
	return resolver.snapshot, nil
}
