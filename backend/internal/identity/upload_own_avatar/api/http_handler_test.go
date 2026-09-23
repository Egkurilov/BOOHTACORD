package uploadavatarapi

import (
	"context"
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	uploadownavatar "voice-platform/backend/internal/identity/upload_own_avatar"
)

func TestUploadUsesAuthenticatedAccountAndReturnsNoStorageKey(t *testing.T) {
	var captured uploadownavatar.Input
	handler := NewUploadHandler(uploaderFunc(func(_ context.Context, input uploadownavatar.Input) (string, error) {
		captured = input
		return "private-key", nil
	}))
	request := httptest.NewRequest(http.MethodPut, "/api/v1/me/avatar", strings.NewReader("image bytes"))
	request.Header.Set("Content-Type", "image/png")
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent || captured.AccountID != "account-1" || recorder.Body.Len() != 0 || strings.Contains(recorder.Body.String(), "private-key") {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, captured, recorder.Body.String())
	}
}

func TestUploadRejectsMissingSessionWrongContentTypeAndOversize(t *testing.T) {
	for _, test := range []struct {
		body, contentType string
		authenticated     bool
	}{{"image", "image/png", false}, {"image", "image/gif", true}, {strings.Repeat("x", maxAvatarUpload+1), "image/png", true}} {
		called := false
		handler := NewUploadHandler(uploaderFunc(func(context.Context, uploadownavatar.Input) (string, error) { called = true; return "", nil }))
		request := httptest.NewRequest(http.MethodPut, "/api/v1/me/avatar", strings.NewReader(test.body))
		request.Header.Set("Content-Type", test.contentType)
		if test.authenticated {
			request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account-1", SessionDigest: [sha256.Size]byte{0: 1}}))
		}
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		want := http.StatusBadRequest
		if !test.authenticated {
			want = http.StatusUnauthorized
		}
		if recorder.Code != want || called {
			t.Fatalf("status=%d want=%d called=%v", recorder.Code, want, called)
		}
	}
}

type uploader interface {
	Upload(context.Context, uploadownavatar.Input) (string, error)
}
type uploaderFunc func(context.Context, uploadownavatar.Input) (string, error)

func (function uploaderFunc) Upload(ctx context.Context, input uploadownavatar.Input) (string, error) {
	return function(ctx, input)
}
