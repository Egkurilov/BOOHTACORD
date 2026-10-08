package managevoicetimeoutapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

type serviceStub struct {
	calls int
	err   error
	input timeout.Input
}

func (s *serviceStub) Set(_ context.Context, in timeout.Input) (timeout.State, error) {
	s.calls++
	s.input = in
	return timeout.State{Active: true, RevocationPending: true}, s.err
}
func (s *serviceStub) Clear(_ context.Context, in timeout.Input) (timeout.State, error) {
	s.calls++
	return timeout.State{}, s.err
}
func (s *serviceStub) Read(_ context.Context, in timeout.Input) (timeout.State, error) {
	s.calls++
	return timeout.State{}, s.err
}
func req(method, body string) *http.Request {
	r := httptest.NewRequest(method, "/", strings.NewReader(body))
	r.SetPathValue("accountID", "target")
	return r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "actor", SessionDigest: [32]byte{1}}))
}
func TestCommittedIntentNeverClaimsPhysicalRemoval(t *testing.T) {
	s := &serviceStub{}
	w := httptest.NewRecorder()
	NewHandler(s).ServeHTTP(w, req("PUT", `{"expires_at":"2026-10-09T00:00:00Z","reason_code":"SPAM"}`))
	if w.Code != 202 || !strings.Contains(w.Body.String(), `"revocation_pending":true`) || s.calls != 1 {
		t.Fatal(w.Code, w.Body.String())
	}
}
func TestTimeoutErrorsAreSanitized(t *testing.T) {
	for _, c := range []struct {
		err    error
		status int
	}{{timeout.ErrForbidden, 403}, {timeout.ErrUnauthenticated, 401}, {timeout.ErrInvalidInput, 400}, {timeout.ErrNotFound, 404}, {errors.New("private secret"), 500}} {
		w := httptest.NewRecorder()
		NewHandler(&serviceStub{err: c.err}).ServeHTTP(w, req("DELETE", ""))
		if w.Code != c.status || strings.Contains(w.Body.String(), "private secret") {
			t.Fatal(w.Code, w.Body.String())
		}
	}
}
func TestDecoderRejectsFreeTextAndTrailingJSON(t *testing.T) {
	for _, body := range []string{`{"reason":"private text"}`, `{"expires_at":"2026-10-09T00:00:00Z","reason_code":"OTHER"} {}`} {
		s := &serviceStub{}
		w := httptest.NewRecorder()
		NewHandler(s).ServeHTTP(w, req("PUT", body))
		if w.Code != 400 || s.calls != 0 {
			t.Fatal(w.Code, s.calls)
		}
	}
}
