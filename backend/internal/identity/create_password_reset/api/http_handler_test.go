package resetapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/create_password_reset"
)

func TestHandlerReturnsOneTimeURLWithSecretInFragment(t *testing.T) {
	var captured createpasswordreset.Input
	handler := NewHandler(creatorFunc(func(_ context.Context, input createpasswordreset.Input) (createpasswordreset.Result, error) {
		captured = input
		return createpasswordreset.Result{Token: "opaque_reset", ExpiresAt: time.Date(2026, time.September, 17, 10, 30, 0, 0, time.UTC)}, nil
	}), "https://voice.example.test")

	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/password-reset-links", strings.NewReader(`{"account_id":"77b14148-7723-4c14-8e69-20a5d9b77972"}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "3ee2a31b-56c8-4361-ad89-5d7582f57062", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated || captured.AccountID != "77b14148-7723-4c14-8e69-20a5d9b77972" {
		t.Fatalf("status = %d, input = %#v", recorder.Code, captured)
	}
	if captured.ActorID != "3ee2a31b-56c8-4361-ad89-5d7582f57062" {
		t.Fatalf("actor ID = %q", captured.ActorID)
	}
	if !strings.Contains(recorder.Body.String(), `https://voice.example.test/reset-password#token=opaque_reset`) || strings.Contains(recorder.Body.String(), "?") {
		t.Fatalf("body = %q", recorder.Body.String())
	}
}

func TestHandlerRejectsMalformedRequest(t *testing.T) {
	handler := NewHandler(creatorFunc(func(context.Context, createpasswordreset.Input) (createpasswordreset.Result, error) {
		t.Fatal("creator must not be called")
		return createpasswordreset.Result{}, nil
	}), "https://voice.example.test")
	request := httptest.NewRequest(http.MethodPost, "/api/v1/admin/password-reset-links", strings.NewReader(`{"account_id":""}`))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", recorder.Code)
	}
}

type creatorFunc func(context.Context, createpasswordreset.Input) (createpasswordreset.Result, error)

func (function creatorFunc) Create(context context.Context, input createpasswordreset.Input) (createpasswordreset.Result, error) {
	return function(context, input)
}
