package admitupload

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestLimiterCapsPerAccountAndDeploymentAndReleasesEverySlot(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 2, AccountLimit: 1})
	if err != nil {
		t.Fatal(err)
	}
	releaseA, ok := limiter.TryAcquire("account-a")
	if !ok {
		t.Fatal("first upload rejected")
	}
	if _, ok := limiter.TryAcquire("account-a"); ok {
		t.Fatal("per-account upload limit exceeded")
	}
	releaseB, ok := limiter.TryAcquire("account-b")
	if !ok {
		t.Fatal("one account consumed another account's slot")
	}
	if _, ok := limiter.TryAcquire("account-c"); ok {
		t.Fatal("deployment limit exceeded")
	}
	releaseA()
	if _, ok := limiter.TryAcquire("account-c"); !ok {
		t.Fatal("released global slot stayed occupied")
	}
	releaseB()
}

func TestMiddlewareRejectsConcurrentRequestWithRetryAfterAndReleases(t *testing.T) {
	limiter, err := New(Config{GlobalLimit: 1, AccountLimit: 1})
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/upload", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "account"}))
	release, acquired := limiter.TryAcquire("account")
	if !acquired {
		t.Fatal("could not reserve test slot")
	}
	response := httptest.NewRecorder()
	limiter.Middleware(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Fatal("over-quota handler was called") })).ServeHTTP(response, request)
	if response.Code != http.StatusTooManyRequests || response.Header().Get("Retry-After") != "1" {
		t.Fatalf("response = %d %#v", response.Code, response.Header())
	}
	release()
	response = httptest.NewRecorder()
	limiter.Middleware(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })).ServeHTTP(response, request)
	if response.Code != http.StatusNoContent {
		t.Fatalf("status after release = %d", response.Code)
	}
}
