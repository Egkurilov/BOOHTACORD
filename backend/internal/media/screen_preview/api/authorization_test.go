package screenpreviewapi

import (
	"bytes"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/identity/session"
)

func TestDeniedReadIsPrivateAndDoesNotExposeAuthorizationDetails(t *testing.T) {
	ops := &operationsStub{err: errors.New("private authorization detail")}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, ops)
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/screen-previews/v1/leases/12f2f7b4-59ca-430e-883e-f9fab5c6c56f/7e78d5a0-1ba9-4c18-b268-8b03e3c6e5f0", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusServiceUnavailable || bytes.Contains(response.Body.Bytes(), []byte("private authorization detail")) {
		t.Fatalf("error response = %d %s", response.Code, response.Body.String())
	}
	assertPrivateHeaders(t, response)
}
