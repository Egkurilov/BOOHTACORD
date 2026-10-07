package observeincidents

import (
	"errors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestFixedOperationsKeepSuccessOnFailureAndUnknownAbsent(t *testing.T) {
	m := New()
	now := time.Unix(100, 0)
	m.now = func() time.Time { return now }
	r := prometheus.NewRegistry()
	r.MustRegister(m)
	m.Observe("livekit_snapshot", time.Millisecond, nil)
	now = time.Unix(200, 0)
	m.Observe("livekit_snapshot", time.Millisecond, errors.New("private-room"))
	m.Observe("private-operation", time.Millisecond, nil)
	w := httptest.NewRecorder()
	promhttp.HandlerFor(r, promhttp.HandlerOpts{}).ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	out := w.Body.String()
	for _, want := range []string{`voice_platform_incident_last_attempt_timestamp_seconds{operation="livekit_snapshot"} 200`, `voice_platform_incident_last_success_timestamp_seconds{operation="livekit_snapshot"} 100`, `voice_platform_incident_last_successful{operation="livekit_snapshot"} 0`} {
		if !strings.Contains(out, want) {
			t.Fatal(out)
		}
	}
	for _, bad := range []string{"private-room", "private-operation", "storage_snapshot"} {
		if strings.Contains(out, bad) {
			t.Fatalf("unexpected %s", out)
		}
	}
}
