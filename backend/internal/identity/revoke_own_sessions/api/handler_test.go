package revokesessionapi

import (
	"context"
	"github.com/google/uuid"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	"voice-platform/backend/internal/identity/session"
)

type fakeStore struct {
	input  revoke.Input
	calls  int
	result revoke.Result
	err    error
}

func (s *fakeStore) Revoke(_ context.Context, input revoke.Input) (revoke.Result, error) {
	s.calls++
	s.input = input
	return s.result, s.err
}
func TestRevokeUsesCallerAndCurrentCookieIsClearedOnlyWhenRevoked(t *testing.T) {
	for _, self := range []bool{false, true} {
		store := &fakeStore{result: revoke.Result{Count: 1, CurrentRevoked: self}}
		request := httptest.NewRequest("DELETE", "/api/v1/me/sessions/selected", nil)
		request.Header.Set("X-Account-ID", "caller")
		request.SetPathValue("sessionID", uuid.NewString())
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "caller"}))
		response := httptest.NewRecorder()
		New(store).ServeHTTP(response, request)
		if response.Code != 204 || store.input.AccountID != "caller" || store.input.Others {
			t.Fatal("selected revoke boundary failed")
		}
		cookies := response.Result().Cookies()
		if self && (len(cookies) != 1 || cookies[0].Name != session.CookieName || cookies[0].MaxAge != -1 || !cookies[0].Secure || !cookies[0].HttpOnly) {
			t.Fatal("current cookie not securely cleared")
		}
		if !self && len(cookies) != 0 {
			t.Fatal("initiating cookie cleared")
		}
	}
}
func TestRevokeOthersNeverAcceptsClientAccountOrSessionIDs(t *testing.T) {
	store := &fakeStore{}
	request := httptest.NewRequest("POST", "/api/v1/me/sessions/revoke-others", nil)
	request.Header.Set("X-Account-ID", "caller")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "caller"}))
	response := httptest.NewRecorder()
	New(store).ServeHTTP(response, request)
	if response.Code != 204 || !store.input.Others || store.input.SessionID != "" || store.input.AccountID != "caller" {
		t.Fatal("revoke others boundary failed")
	}
}
func TestForeignOrRevokedHandlesReturnSafeErrors(t *testing.T) {
	for _, row := range []struct {
		err    error
		status int
	}{{revoke.ErrNotFound, 404}, {revoke.ErrUnauthenticated, 401}} {
		store := &fakeStore{err: row.err}
		request := httptest.NewRequest("DELETE", "/api/v1/me/sessions/selected", nil)
		request.Header.Set("X-Account-ID", "caller")
		request.SetPathValue("sessionID", uuid.NewString())
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "caller"}))
		response := httptest.NewRecorder()
		New(store).ServeHTTP(response, request)
		if response.Code != row.status {
			t.Fatal("session error mapping failed")
		}
	}
}
