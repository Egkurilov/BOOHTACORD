package acquirevoiceleaseapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	acquirevoicelease "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func TestHandlerCreatesLeaseWithExplicitTransfer(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	var captured acquirevoicelease.Input
	handler := NewHandler(acquirerFunc(func(_ context.Context, input acquirevoicelease.Input) (acquirevoicelease.Result, error) {
		captured = input
		return acquirevoicelease.Result{ID: "lease-1", ChannelID: input.ChannelID, Transferred: true}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice/channels/voice-1/leases", strings.NewReader(`{"transfer":true}`))
	request.SetPathValue("channelID", "voice-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1", SessionDigest: digest}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusCreated || !captured.Transfer || captured.SessionDigest != digest || !strings.Contains(recorder.Body.String(), `"transferred":true`) {
		t.Fatalf("status = %d, input = %#v, body = %q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestHandlerReportsExistingVoiceChannelWithoutTransfer(t *testing.T) {
	handler := NewHandler(acquirerFunc(func(context.Context, acquirevoicelease.Input) (acquirevoicelease.Result, error) {
		return acquirevoicelease.Result{ExistingChannelID: "voice-old"}, acquirevoicelease.ErrActiveLease
	}))
	request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1", SessionDigest: sha256.Sum256([]byte("session"))}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusConflict || !strings.Contains(recorder.Body.String(), `"active_channel_id":"voice-old"`) {
		t.Fatalf("status = %d, body = %q", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRejectsUnknownFields(t *testing.T) {
	called := false
	handler := NewHandler(acquirerFunc(func(context.Context, acquirevoicelease.Input) (acquirevoicelease.Result, error) {
		called = true
		return acquirevoicelease.Result{}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"takeover":true}`))
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusBadRequest || called {
		t.Fatalf("status = %d, called = %v", recorder.Code, called)
	}
}

type acquirerFunc func(context.Context, acquirevoicelease.Input) (acquirevoicelease.Result, error)

func (function acquirerFunc) Acquire(context context.Context, input acquirevoicelease.Input) (acquirevoicelease.Result, error) {
	return function(context, input)
}
