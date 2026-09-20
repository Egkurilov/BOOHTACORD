package resetapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/complete_password_reset"
)

func TestHandlerCompletesResetWithoutReturningSecret(t *testing.T) {
	var captured completepasswordreset.Input
	handler := NewHandler(completerFunc(func(_ context.Context, input completepasswordreset.Input) error {
		captured = input
		return nil
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/password-reset/complete", strings.NewReader(`{"token":"opaque-reset-token","password":"new correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent || captured.Token != "opaque-reset-token" || captured.Password != "new correct horse battery staple" || recorder.Body.Len() != 0 {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerDoesNotRevealInvalidOrExpiredReset(t *testing.T) {
	handler := NewHandler(completerFunc(func(context.Context, completepasswordreset.Input) error {
		return completepasswordreset.ErrInvalidOrExpired
	}))

	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/password-reset/complete", strings.NewReader(`{"token":"opaque-reset-token","password":"new correct horse battery staple"}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest || !strings.Contains(recorder.Body.String(), `"VALIDATION_FAILED"`) || strings.Contains(recorder.Body.String(), "expired") {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRejectsUnknownFields(t *testing.T) {
	handler := NewHandler(completerFunc(func(context.Context, completepasswordreset.Input) error { return errors.New("must not be called") }))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/auth/password-reset/complete", strings.NewReader(`{"token":"opaque-reset-token","password":"new correct horse battery staple","extra":true}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type completerFunc func(context.Context, completepasswordreset.Input) error

func (function completerFunc) Complete(context context.Context, input completepasswordreset.Input) error {
	return function(context, input)
}
