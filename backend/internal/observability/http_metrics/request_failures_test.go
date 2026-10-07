package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRouteMetricsIncludePanicAndOriginFailure(t *testing.T) {
	m := New()
	mux := http.NewServeMux()
	mux.HandleFunc("POST /items/{id}", func(http.ResponseWriter, *http.Request) { panic("private") })
	h := m.Middleware(mux, mux)
	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("panic swallowed")
			}
		}()
		h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/items/private", nil))
	}()
	denied := m.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(403) }), mux)
	denied.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/items/private", nil))
	out := scrapeMetrics(m)
	for _, status := range []string{"500", "403"} {
		if !strings.Contains(out, `route="/items/{id}",status="`+status+`"} 1`) {
			t.Fatal(out)
		}
	}
}
