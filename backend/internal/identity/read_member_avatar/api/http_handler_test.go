package readavatarapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerServesPrivatePNGOnlyToAuthenticatedGuildMember(t *testing.T) {
	var accountID string
	handler := NewHandler(readerFunc(func(_ context.Context, id string) ([]byte, error) { accountID = id; return []byte("png"), nil }))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/members/member-1/avatar", nil)
	request.SetPathValue("userID", "member-1")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "viewer-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || accountID != "member-1" || recorder.Header().Get("Content-Type") != "image/png" || recorder.Header().Get("X-Content-Type-Options") != "nosniff" || recorder.Body.String() != "png" {
		t.Fatalf("status=%d id=%q headers=%v body=%q", recorder.Code, accountID, recorder.Header(), recorder.Body.String())
	}
}

func TestHandlerRequiresSessionAndDoesNotRevealMissingAvatar(t *testing.T) {
	handler := NewHandler(readerFunc(func(context.Context, string) ([]byte, error) { return nil, ErrNotFound }))
	for _, test := range []struct {
		authenticated bool
		status        int
	}{{false, http.StatusUnauthorized}, {true, http.StatusNotFound}} {
		request := httptest.NewRequest(http.MethodGet, "/api/v1/members/member-1/avatar", nil)
		request.SetPathValue("userID", "member-1")
		if test.authenticated {
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "viewer-1"}))
		}
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != test.status {
			t.Fatalf("status=%d want=%d", recorder.Code, test.status)
		}
	}
}

type readerFunc func(context.Context, string) ([]byte, error)

func (function readerFunc) Read(ctx context.Context, id string) ([]byte, error) {
	return function(ctx, id)
}
