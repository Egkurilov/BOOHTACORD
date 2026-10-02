package rolepolicyapi

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestRolesHandlerReturnsImmutableAdministratorAndEditableMember(t *testing.T) {
	response := httptest.NewRecorder()
	NewRolesHandler(fakeReader{permissionregistry.MemberDefaults(6)}).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/admin/roles", nil))
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"revision":6`) || !strings.Contains(response.Body.String(), `"editable":false`) || !strings.Contains(response.Body.String(), `"editable":true`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

func TestUpdateHandlerRejectsIncompleteMapAndUpdatesMember(t *testing.T) {
	handler := NewUpdateHandler(&fakeUpdater{result: permissionregistry.Policy{TextCreate: true, Revision: 7}})
	for _, body := range []string{`{"expected_revision":6,"permissions":{"channel.text.create":true}}`, `{"expected_revision":6,"permissions":{"channel.text.create":true,"channel.text.delete":false,"channel.voice.create":true,"channel.voice.delete":false,"category.create":true,"category.delete":false,"unknown":true}}`} {
		response := serveUpdate(handler, body, "MEMBER")
		if response.Code != http.StatusBadRequest {
			t.Fatalf("invalid response = %d %s", response.Code, response.Body.String())
		}
	}
	response := serveUpdate(handler, `{"expected_revision":6,"permissions":{"channel.text.create":true,"channel.text.delete":false,"channel.voice.create":true,"channel.voice.delete":false,"category.create":true,"category.delete":false}}`, "MEMBER")
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"revision":7`) {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

func TestUpdateHandlerRejectsAdministratorPreset(t *testing.T) {
	response := serveUpdate(NewUpdateHandler(&fakeUpdater{}), `{}`, "ADMINISTRATOR")
	if response.Code != http.StatusForbidden || !strings.Contains(response.Body.String(), "ROLE_IMMUTABLE") {
		t.Fatalf("response = %d %s", response.Code, response.Body.String())
	}
}

func serveUpdate(handler http.Handler, body, role string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPut, "/api/v1/admin/roles/"+role+"/permissions", bytes.NewBufferString(body))
	request.SetPathValue("role", role)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "admin-1", Role: "ADMINISTRATOR"}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

type fakeReader struct{ policy permissionregistry.Policy }

func (reader fakeReader) LoadMember(context.Context) (permissionregistry.Policy, error) {
	return reader.policy, nil
}

type fakeUpdater struct{ result permissionregistry.Policy }

func (updater *fakeUpdater) UpdateMember(context.Context, rolepolicy.UpdateCommand) (permissionregistry.Policy, error) {
	return updater.result, nil
}
