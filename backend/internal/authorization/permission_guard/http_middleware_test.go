package permissionguard

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	effectivepermissions "voice-platform/backend/internal/authorization/effective_permissions"
	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestRequireUsesCurrentPermissionSnapshot(t *testing.T) {
	resolver := fakeResolver{permissions: map[permissionregistry.Permission]bool{permissionregistry.CategoryCreate: true}}
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	for _, scenario := range []struct {
		permission permissionregistry.Permission
		status     int
	}{{permissionregistry.CategoryCreate, 204}, {permissionregistry.CategoryDelete, 403}} {
		request := memberRequest(`{}`)
		response := httptest.NewRecorder()
		Require(resolver, scenario.permission)(next).ServeHTTP(response, request)
		if response.Code != scenario.status {
			t.Fatalf("%s status = %d", scenario.permission, response.Code)
		}
	}
}

func TestRequireChannelCreateSelectsPermissionFromBodyAndRestoresIt(t *testing.T) {
	resolver := fakeResolver{permissions: map[permissionregistry.Permission]bool{permissionregistry.ChannelVoiceCreate: true}}
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_, _ = w.Write(body)
	})
	request := memberRequest(`{"kind":"VOICE","name":"Голос"}`)
	response := httptest.NewRecorder()
	RequireChannelCreate(resolver)(next).ServeHTTP(response, request)
	if response.Code != http.StatusOK || response.Body.String() != `{"kind":"VOICE","name":"Голос"}` {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

type fakeResolver struct {
	permissions map[permissionregistry.Permission]bool
}

func (resolver fakeResolver) Resolve(context.Context, effectivepermissions.Principal) (effectivepermissions.Snapshot, error) {
	return effectivepermissions.Snapshot{Permissions: resolver.permissions}, nil
}

func memberRequest(body string) *http.Request {
	request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body))
	return request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "member-1", Role: "MEMBER"}))
}
