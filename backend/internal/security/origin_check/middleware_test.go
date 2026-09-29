package origincheck

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMiddlewareAllowsSafeMethodsAndExactConfiguredOrigin(t *testing.T) {
	middleware, err := New("https://voice.example.test")
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	next := http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })

	for _, request := range []*http.Request{
		httptest.NewRequest(http.MethodGet, "/", nil),
		func() *http.Request {
			request := httptest.NewRequest(http.MethodPost, "/", nil)
			request.Header.Set("Origin", "https://voice.example.test")
			return request
		}(),
	} {
		recorder := httptest.NewRecorder()
		middleware(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusNoContent {
			t.Fatalf("status = %d", recorder.Code)
		}
	}
}

func TestMiddlewareRejectsMissingOrForeignOriginForMutation(t *testing.T) {
	middleware, err := New("https://voice.example.test")
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Fatal("next must not run") })

	for _, origin := range []string{"", "https://attacker.example"} {
		request := httptest.NewRequest(http.MethodPost, "/", nil)
		if origin != "" {
			request.Header.Set("Origin", origin)
		}
		recorder := httptest.NewRecorder()
		middleware(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusForbidden {
			t.Fatalf("origin %q status = %d", origin, recorder.Code)
		}
	}
}

func TestMiddlewarePassesOnlyPrivateWebhookWithoutBrowserOrigin(t *testing.T) {
	middleware, _ := New("https://voice.example.test")
	next := http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })
	for _, path := range []string{"/internal/livekit/roster", "/internal/livekit/other"} {
		recorder := httptest.NewRecorder()
		middleware(next).ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, path, nil))
		if path == "/internal/livekit/roster" && recorder.Code != http.StatusNoContent {
			t.Fatalf("webhook status=%d", recorder.Code)
		}
		if path != "/internal/livekit/roster" && recorder.Code != http.StatusForbidden {
			t.Fatalf("other status=%d", recorder.Code)
		}
	}
}
