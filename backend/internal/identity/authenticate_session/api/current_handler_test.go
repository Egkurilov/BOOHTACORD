package sessionapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
)

func TestCurrentHandlerReturnsVerifiedPrincipal(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil)
	context := context.WithValue(request.Context(), principalKey{}, authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER"})
	recorder := httptest.NewRecorder()

	CurrentHandler().ServeHTTP(recorder, request.WithContext(context))

	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"account_id":"account-1"`) || !strings.Contains(recorder.Body.String(), `"role":"MEMBER"`) {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
}

func TestCurrentHandlerReturnsAnonymousSessionWithoutPrincipal(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/v1/auth/session", nil)
	recorder := httptest.NewRecorder()

	CurrentHandler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || strings.TrimSpace(recorder.Body.String()) != `{"authenticated":false}` {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
}
