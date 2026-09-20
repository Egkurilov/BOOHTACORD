package releasevoiceleaseapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	releasevoicelease "voice-platform/backend/internal/voice/release_voice_lease"
)

func TestHandlerReleasesOnlyAuthenticatedSessionLease(t *testing.T) {
	digest := sha256.Sum256([]byte("session"))
	var captured releasevoicelease.Input
	handler := NewHandler(releaserFunc(func(_ context.Context, input releasevoicelease.Input) error { captured = input; return nil }))
	request := httptest.NewRequest(http.MethodDelete, "/api/v1/voice/leases/lease-1", nil)
	request.SetPathValue("leaseID", "lease-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "user-1", SessionDigest: digest}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || captured.LeaseID != "lease-1" || captured.SessionDigest != digest {
		t.Fatalf("status = %d, input = %#v", recorder.Code, captured)
	}
}

type releaserFunc func(context.Context, releasevoicelease.Input) error

func (function releaserFunc) Release(context context.Context, input releasevoicelease.Input) error {
	return function(context, input)
}
