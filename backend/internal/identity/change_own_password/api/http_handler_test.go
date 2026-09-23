package changepasswordapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	changeownpassword "voice-platform/backend/internal/identity/change_own_password"
)

func TestHandlerUsesCurrentSessionAndNeverReturnsPasswordData(t *testing.T) {
	var captured changeownpassword.Input
	handler := NewHandler(changerFunc(func(_ context.Context, input changeownpassword.Input) error {
		captured = input
		return nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/me/password", strings.NewReader(`{"current_password":"old secure password","new_password":"new secure password"}`))
	digest := [sha256.Size]byte{0: 9}
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER", SessionDigest: digest}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || captured.AccountID != "account-1" || captured.CurrentSessionDigest != digest || recorder.Body.Len() != 0 || strings.Contains(recorder.Body.String(), "password") {
		t.Fatalf("status = %d, input = %#v, body length = %d", recorder.Code, captured, recorder.Body.Len())
	}
}

func TestHandlerRejectsMalformedOrUnknownPasswordFieldsBeforeChange(t *testing.T) {
	for _, body := range []string{`{"current_password":"old secure password"}`, `{"current_password":"old secure password","new_password":"new secure password","role":"ADMINISTRATOR"}`, `{"current_password":"old secure password","new_password":"new secure password"} {}`} {
		called := false
		handler := NewHandler(changerFunc(func(context.Context, changeownpassword.Input) error { called = true; return nil }))
		request := httptest.NewRequest(http.MethodPost, "/api/v1/me/password", strings.NewReader(body))
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", Role: "MEMBER", SessionDigest: [sha256.Size]byte{0: 9}}))
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusBadRequest || called {
			t.Fatalf("status = %d, called = %v", recorder.Code, called)
		}
	}
}

func TestHandlerRequiresAuthenticatedSession(t *testing.T) {
	called := false
	handler := NewHandler(changerFunc(func(context.Context, changeownpassword.Input) error { called = true; return nil }))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/v1/me/password", strings.NewReader("{}")))
	if recorder.Code != http.StatusUnauthorized || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

type changerFunc func(context.Context, changeownpassword.Input) error

func (function changerFunc) Change(context context.Context, input changeownpassword.Input) error {
	return function(context, input)
}
