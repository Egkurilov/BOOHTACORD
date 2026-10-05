package revokesessionapi

import (
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestAccountSwitchCannotApplyOldInterfaceRevokeToNewCookieOwner(t *testing.T) {
	for _, expected := range []string{"", "old-account"} {
		store := &fakeStore{}
		request := httptest.NewRequest("POST", "/api/v1/me/sessions/revoke-others", nil)
		request.Header.Set("X-Account-ID", expected)
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "new-account"}))
		response := httptest.NewRecorder()
		New(store).ServeHTTP(response, request)
		if response.Code < 400 || store.calls != 0 {
			t.Fatal("stale interface revoked new account sessions")
		}
	}
}
