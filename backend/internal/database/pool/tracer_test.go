package pool

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAcquireOutcomesAndPendingArePrivate(t *testing.T) {
	m := NewMetrics()
	r := prometheus.NewRegistry()
	r.MustRegister(m)
	for _, err := range []error{nil, errors.New("postgres://private?password=secret"), context.DeadlineExceeded, context.Canceled} {
		ctx := m.TraceAcquireStart(context.Background(), nil, pgxpool.TraceAcquireStartData{})
		m.TraceAcquireEnd(ctx, nil, pgxpool.TraceAcquireEndData{Err: err})
	}
	w := httptest.NewRecorder()
	promhttp.HandlerFor(r, promhttp.HandlerOpts{}).ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	out := w.Body.String()
	for _, v := range []string{`outcome="success"} 1`, `outcome="failure"} 1`, `outcome="timeout"} 1`, `outcome="canceled"} 1`, "voice_platform_database_acquires_pending 0"} {
		if !strings.Contains(out, v) {
			t.Fatal(out)
		}
	}
	for _, bad := range []string{"postgres://", "private", "secret"} {
		if strings.Contains(out, bad) {
			t.Fatal("leak")
		}
	}
}
