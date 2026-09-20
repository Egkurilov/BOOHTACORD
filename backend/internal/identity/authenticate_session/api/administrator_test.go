package sessionapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
)

func TestRequireAdministratorRejectsMember(t *testing.T) {
	called := false
	handler := RequireAdministrator(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }))
	request := httptest.NewRequest(http.MethodPost, "/admin", nil).WithContext(context.WithValue(context.Background(), principalKey{}, authenticatesession.Principal{Role: "MEMBER"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusForbidden || called || !strings.Contains(recorder.Body.String(), `"FORBIDDEN"`) {
		t.Fatalf("status = %d, called = %v, body = %q", recorder.Code, called, recorder.Body.String())
	}
}

func TestRequireAdministratorAllowsAdministrator(t *testing.T) {
	called := false
	handler := RequireAdministrator(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		called = true
		writer.WriteHeader(http.StatusNoContent)
	}))
	request := httptest.NewRequest(http.MethodPost, "/admin", nil).WithContext(context.WithValue(context.Background(), principalKey{}, authenticatesession.Principal{Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || !called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}
