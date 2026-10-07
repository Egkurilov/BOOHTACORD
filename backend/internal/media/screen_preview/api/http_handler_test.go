package screenpreviewapi

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

type authStub struct{}

func (authStub) Authenticate(_ context.Context, token string) (authenticatesession.Principal, error) {
	if token != "valid-session" {
		return authenticatesession.Principal{}, authenticatesession.ErrUnauthenticated
	}
	return authenticatesession.Principal{AccountID: "viewer", SessionDigest: [32]byte{1}}, nil
}

type operationsStub struct {
	preview screenpreview.Preview
	err     error
	uploads int
	after   uint64
}

func (stub *operationsStub) Begin(context.Context, screenpreview.Principal, string) (screenpreview.Generation, error) {
	return screenpreview.Generation{SchemaVersion: 1, GenerationID: "d9428888-122b-4ce8-a5a7-08f3eaf42f0d"}, stub.err
}
func (stub *operationsStub) Upload(_ context.Context, _ screenpreview.Principal, _, _ string, _ uint64, body []byte) error {
	stub.uploads++
	if len(body) > screenpreview.MaxJPEGBytes {
		return screenpreview.ErrInvalidJPEG
	}
	return stub.err
}
func (stub *operationsStub) Read(_ context.Context, _ screenpreview.Principal, _, _ string, after uint64) (screenpreview.Preview, error) {
	stub.after = after
	if stub.err != nil {
		return screenpreview.Preview{}, stub.err
	}
	if after >= stub.preview.Revision {
		return screenpreview.Preview{Revision: stub.preview.Revision}, screenpreview.ErrNoUpdate
	}
	return stub.preview, stub.err
}
func (stub *operationsStub) Invalidate(context.Context, screenpreview.Principal, string, string) error {
	return stub.err
}

func TestReadDeliversNoStoreJPEGAndUsesLatestRevisionHint(t *testing.T) {
	ops := &operationsStub{preview: screenpreview.Preview{JPEG: []byte{0xff, 0xd8, 0xff, 0xd9}, Revision: 7}}
	mux := http.NewServeMux()
	RegisterRoutes(mux, authStub{}, ops)
	path := "/api/v1/voice/screen-previews/v1/leases/12f2f7b4-59ca-430e-883e-f9fab5c6c56f/7e78d5a0-1ba9-4c18-b268-8b03e3c6e5f0"
	request := httptest.NewRequest(http.MethodGet, path+"?after_revision=6", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusOK || !bytes.Equal(response.Body.Bytes(), ops.preview.JPEG) {
		t.Fatalf("response = %d %v", response.Code, response.Body.Bytes())
	}
	if response.Header().Get("Content-Type") != "image/jpeg" || response.Header().Get("X-Screen-Preview-Revision") != "7" {
		t.Fatalf("preview headers = %#v", response.Header())
	}
	assertPrivateHeaders(t, response)
	request = httptest.NewRequest(http.MethodGet, path+"?after_revision=7", nil)
	request.AddCookie(&http.Cookie{Name: session.CookieName, Value: "valid-session"})
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != http.StatusNoContent || response.Body.Len() != 0 || ops.after != 7 {
		t.Fatalf("unchanged preview response = %d %q", response.Code, response.Body.String())
	}
}

func assertPrivateHeaders(t *testing.T, response *httptest.ResponseRecorder) {
	t.Helper()
	if response.Header().Get("Cache-Control") != "private, no-store, max-age=0" || response.Header().Get("X-Content-Type-Options") != "nosniff" || response.Header().Get("Vary") != "Cookie" {
		t.Fatalf("private headers missing: %#v", response.Header())
	}
}
