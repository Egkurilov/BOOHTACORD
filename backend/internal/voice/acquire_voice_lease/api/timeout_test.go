package acquirevoiceleaseapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	acquire "voice-platform/backend/internal/voice/acquire_voice_lease"
)

func TestVoiceTimeoutIsConflictWithoutExpiringSession(t *testing.T) {
	handler := NewHandler(acquirerFunc(func(context.Context, acquire.Input) (acquire.Result, error) {
		return acquire.Result{}, acquire.ErrVoiceTimeout
	}))
	r := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{}`))
	r = r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "actor", SessionDigest: [32]byte{1}}))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, r)
	if w.Code != 409 || !strings.Contains(w.Body.String(), `"VOICE_TIMEOUT"`) || strings.Contains(w.Body.String(), "UNAUTHENTICATED") {
		t.Fatal(w.Code, w.Body.String())
	}
}
