package updateprofileapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	updateownprofile "voice-platform/backend/internal/identity/update_own_profile"
)

func TestHandlerUpdatesTheAuthenticatedAccountDisplayName(t *testing.T) {
	var captured updateownprofile.Input
	handler := NewHandler(updaterFunc(func(_ context.Context, input updateownprofile.Input) (updateownprofile.Profile, error) {
		captured = input
		return updateownprofile.Profile{AccountID: input.AccountID, Login: "immutable", DisplayName: input.DisplayName, Role: "MEMBER", Revision: 9}, nil
	}))
	request := httptest.NewRequest(http.MethodPatch, "/api/v1/me", strings.NewReader(`{"display_name":"Новое имя"}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured != (updateownprofile.Input{AccountID: "account-1", DisplayName: "Новое имя"}) || !strings.Contains(recorder.Body.String(), `"login":"immutable"`) || !strings.Contains(recorder.Body.String(), `"profile_revision":9`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerRejectsLoginAndUnknownProfileFields(t *testing.T) {
	for _, body := range []string{`{"login":"changed","display_name":"Name"}`, `{"display_name":"Name","role":"ADMINISTRATOR"}`, `{"display_name":"Name"} {}`} {
		called := false
		handler := NewHandler(updaterFunc(func(context.Context, updateownprofile.Input) (updateownprofile.Profile, error) {
			called = true
			return updateownprofile.Profile{}, nil
		}))
		request := httptest.NewRequest(http.MethodPatch, "/api/v1/me", strings.NewReader(body))
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER"}))
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusBadRequest || called {
			t.Fatalf("body %q: status = %d, called = %v", body, recorder.Code, called)
		}
	}
}

func TestHandlerRequiresAnAuthenticatedPrincipal(t *testing.T) {
	called := false
	handler := NewHandler(updaterFunc(func(context.Context, updateownprofile.Input) (updateownprofile.Profile, error) {
		called = true
		return updateownprofile.Profile{}, nil
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPatch, "/api/v1/me", strings.NewReader(`{"display_name":"Имя"}`)))
	if recorder.Code != http.StatusUnauthorized || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

type updaterFunc func(context.Context, updateownprofile.Input) (updateownprofile.Profile, error)

func (function updaterFunc) Update(context context.Context, input updateownprofile.Input) (updateownprofile.Profile, error) {
	return function(context, input)
}
