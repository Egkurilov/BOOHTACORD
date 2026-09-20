package issuelivekitcredentialapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
)

func TestHandlerReturnsCredentialOnlyForCurrentPrincipalLease(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	var captured issuelivekitcredential.Input
	handler := NewHandler(issuerFunc(func(_ context.Context, input issuelivekitcredential.Input) (livekitcredential.Credential, error) {
		captured = input
		return livekitcredential.Credential{URL: "wss://voice.example.test", Token: "test-token", ExpiresAt: time.Date(2026, 9, 17, 12, 1, 0, 0, time.UTC)}, nil
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice/leases/lease-1/credential", nil)
	request.SetPathValue("leaseID", "lease-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1", SessionDigest: digest}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || captured.SessionDigest != digest || captured.LeaseID != "lease-1" || !strings.Contains(recorder.Body.String(), `"token":"test-token"`) {
		t.Fatalf("status = %d, input = %#v, body has token = %v", recorder.Code, captured, strings.Contains(recorder.Body.String(), `"token":"test-token"`))
	}
}

type issuerFunc func(context.Context, issuelivekitcredential.Input) (livekitcredential.Credential, error)

func (function issuerFunc) Issue(context context.Context, input issuelivekitcredential.Input) (livekitcredential.Credential, error) {
	return function(context, input)
}
