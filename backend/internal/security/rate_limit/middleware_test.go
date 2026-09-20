package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMiddlewareLimitsOneForwardedSourceAndResetsWindow(t *testing.T) {
	now := time.Date(2026, time.September, 17, 12, 0, 0, 0, time.UTC)
	limiter, err := New(Config{Limit: 2, Window: time.Minute, MaxSources: 8, Now: func() time.Time { return now }})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	next := http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { writer.WriteHeader(http.StatusNoContent) })

	for attempt := 0; attempt < 2; attempt++ {
		recorder := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodPost, "/", nil)
		request.Header.Set("X-Forwarded-For", "203.0.113.9, 10.0.0.2")
		limiter.Middleware(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusNoContent {
			t.Fatalf("attempt %d status = %d", attempt, recorder.Code)
		}
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/", nil)
	request.Header.Set("X-Forwarded-For", "203.0.113.9")
	limiter.Middleware(next).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusTooManyRequests || recorder.Header().Get("Retry-After") != "60" || !strings.Contains(recorder.Body.String(), `"RATE_LIMITED"`) {
		t.Fatalf("status = %d, retry = %s, body = %s", recorder.Code, recorder.Header().Get("Retry-After"), recorder.Body.String())
	}

	now = now.Add(time.Minute)
	recorder = httptest.NewRecorder()
	limiter.Middleware(next).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("status after window = %d", recorder.Code)
	}
}

func TestMiddlewareDoesNotTrustMalformedForwardedSource(t *testing.T) {
	if source := sourceKey(&http.Request{RemoteAddr: "192.0.2.4:1234", Header: http.Header{"X-Forwarded-For": []string{"not-an-ip"}}}); source != "192.0.2.4" {
		t.Fatalf("source = %q", source)
	}
}
