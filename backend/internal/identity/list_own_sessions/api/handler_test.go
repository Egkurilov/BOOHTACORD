package ownsessionapi

import (
	"context"
	"crypto/sha256"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	ownsessions "voice-platform/backend/internal/identity/list_own_sessions"
)

type fakeStore struct {
	calls int
	owner string
}

func (s *fakeStore) Read(_ context.Context, owner string, _ [sha256.Size]byte, _ string) (ownsessions.Page, error) {
	s.calls++
	s.owner = owner
	return ownsessions.Page{Sessions: []ownsessions.Session{}}, nil
}
func TestReadRequiresAuthenticatedCallerAndNeverCaches(t *testing.T) {
	store := &fakeStore{}
	handler := New(store)
	request := httptest.NewRequest("GET", "/api/v1/me/sessions", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 401 || store.calls != 0 {
		t.Fatal("unauthenticated list permitted")
	}
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "caller"}))
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 200 || response.Header().Get("Cache-Control") != "no-store" || store.owner != "caller" {
		t.Fatal("private list boundary failed")
	}
}
func TestInvalidCursorNeverTouchesRepository(t *testing.T) {
	store := &fakeStore{}
	request := httptest.NewRequest("GET", "/api/v1/me/sessions?cursor=invalid", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "caller"}))
	response := httptest.NewRecorder()
	New(store).ServeHTTP(response, request)
	if response.Code != 400 || store.calls != 0 {
		t.Fatal("invalid session cursor accepted")
	}
}
