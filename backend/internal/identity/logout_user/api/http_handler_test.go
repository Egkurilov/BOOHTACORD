package logoutapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/session"
)

func TestHandlerRevokesCookieTokenAndClearsCookie(t *testing.T) {
	var token string
	handler := NewHandler(logouterFunc(func(_ context.Context, received string) error {
		token = received
		return nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "opaque-token"})
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent || token != "opaque-token" {
		t.Fatalf("status = %d, token = %q", recorder.Code, token)
	}
	cookies := recorder.Result().Cookies()
	if len(cookies) != 1 || cookies[0].Name != session.CookieName || cookies[0].MaxAge >= 0 || !cookies[0].HttpOnly || !cookies[0].Secure || cookies[0].SameSite != http.SameSiteLaxMode || cookies[0].Expires.After(time.Now()) {
		t.Fatalf("cookie = %#v", cookies)
	}
}

func TestHandlerSucceedsWithoutSessionCookie(t *testing.T) {
	called := false
	handler := NewHandler(logouterFunc(func(context.Context, string) error {
		called = true
		return nil
	}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil))
	if recorder.Code != http.StatusNoContent || called {
		t.Fatalf("status = %d, called = %t", recorder.Code, called)
	}
}

type logouterFunc func(context.Context, string) error

func (function logouterFunc) Logout(context context.Context, token string) error {
	return function(context, token)
}
