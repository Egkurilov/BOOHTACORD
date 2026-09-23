package readprofileapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	readownprofile "voice-platform/backend/internal/identity/read_own_profile"
)

func TestHandlerReadsProfileForTheAuthenticatedAccount(t *testing.T) {
	var accountID string
	handler := NewHandler(readerFunc(func(_ context.Context, id string) (readownprofile.Profile, error) {
		accountID = id
		return readownprofile.Profile{AccountID: id, Login: "immutable", DisplayName: "Имя", Role: "MEMBER"}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || accountID != "account-1" || !strings.Contains(recorder.Body.String(), `"display_name":"Имя"`) || strings.Contains(recorder.Body.String(), "password") {
		t.Fatalf("status = %d, account = %q, body = %q", recorder.Code, accountID, recorder.Body.String())
	}
}

func TestHandlerRequiresAnAuthenticatedPrincipal(t *testing.T) {
	called := false
	handler := NewHandler(readerFunc(func(context.Context, string) (readownprofile.Profile, error) {
		called = true
		return readownprofile.Profile{}, nil
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/me", nil))
	if recorder.Code != http.StatusUnauthorized || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

func TestHandlerRejectsOtherMethods(t *testing.T) {
	handler := NewHandler(readerFunc(func(context.Context, string) (readownprofile.Profile, error) { return readownprofile.Profile{}, nil }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/me", strings.NewReader("{}")))
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type readerFunc func(context.Context, string) (readownprofile.Profile, error)

func (function readerFunc) Read(context context.Context, accountID string) (readownprofile.Profile, error) {
	return function(context, accountID)
}
