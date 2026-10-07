package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRecorderPublishesLowCardinalityRequestMetrics(t *testing.T) {
	recorder := New()
	wrapped := recorder.Middleware(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusCreated)
	}))
	wrapped.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/api/v1/channels/secret-id", nil))

	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	if !strings.Contains(metrics, `voice_platform_api_requests_total{method="POST",route="unmatched",status="201"} 1`) {
		t.Fatalf("metrics = %q", metrics)
	}
	if strings.Contains(metrics, "secret-id") || strings.Contains(metrics, "path=") {
		t.Fatalf("metrics leaked a request path or identifier: %q", metrics)
	}
}
