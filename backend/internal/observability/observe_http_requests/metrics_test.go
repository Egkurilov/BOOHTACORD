package observehttprequests

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRouteLabelsAreBounded(t *testing.T) {
	registry := prometheus.NewRegistry()
	m := New(registry)
	mux := http.NewServeMux()
	mux.HandleFunc("GET /items/{id}", func(http.ResponseWriter, *http.Request) {})
	r := httptest.NewRequest("GET", "/items/private?token=secret", nil)
	m.Observe(r, mux, 503, time.Millisecond)
	for i := 0; i < 100; i++ {
		r = httptest.NewRequest("CUSTOM"+strings.Repeat("X", i+1), "/private-path", nil)
		m.Observe(r, mux, 404, time.Millisecond)
	}
	r = httptest.NewRequest("POST", "/api/v1/telemetry/traces", nil)
	m.Observe(r, mux, 503, time.Millisecond)
	w := httptest.NewRecorder()
	promhttp.HandlerFor(registry, promhttp.HandlerOpts{}).ServeHTTP(w, r)
	out := w.Body.String()
	for _, want := range []string{`method="GET",route="/items/{id}",status="503"`, `method="OTHER",route="unmatched",status="404"} 100`, `operation="trace_relay",status="503"`} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %s: %s", want, out)
		}
	}
	for _, bad := range []string{"private", "secret", "CUSTOM"} {
		if strings.Contains(out, bad) {
			t.Fatalf("leaked %s", bad)
		}
	}
}
