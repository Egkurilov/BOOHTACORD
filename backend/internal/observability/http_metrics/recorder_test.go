package httpmetrics

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
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
	if !strings.Contains(metrics, `voice_platform_api_requests_total{method="POST",status="201"} 1`) {
		t.Fatalf("metrics = %q", metrics)
	}
	if strings.Contains(metrics, "secret-id") || strings.Contains(metrics, "path=") {
		t.Fatalf("metrics leaked a request path or identifier: %q", metrics)
	}
}

func TestRecorderPublishesAggregatedSFURevocationMetrics(t *testing.T) {
	recorder := New()
	recorder.ObserveVoiceSFURevocation(2, 1, true)

	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, line := range []string{
		`voice_platform_voice_sfu_revocations_total{outcome="confirmed"} 2`,
		`voice_platform_voice_sfu_revocations_total{outcome="pending"} 1`,
		`voice_platform_voice_sfu_revocations_total{outcome="failed"} 1`,
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	if strings.Contains(metrics, "11111111-1111-4111-8111-111111111111") || strings.Contains(metrics, "22222222-2222-4222-8222-222222222222") {
		t.Fatalf("metrics leaked a voice identity: %q", metrics)
	}
}

func TestRecorderPublishesRosterSnapshotRateAndLatencyWithoutIdentity(t *testing.T) {
	recorder := New()
	recorder.ObserveVoiceRosterSnapshot(42*time.Millisecond, 3, false)
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, want := range []string{
		`voice_platform_voice_roster_snapshots_total{outcome="success"} 1`,
		`voice_platform_voice_roster_snapshot_seconds_count 1`,
		`voice_platform_voice_roster_requested_rooms_count 1`,
	} {
		if !strings.Contains(metrics, want) { t.Fatalf("metrics lack %q", want) }
	}
	if strings.Contains(metrics, "voice:22222222") { t.Fatal("room ID leaked") }
}

func TestRecorderPublishesRealtimeConnectionMetrics(t *testing.T) {
	recorder := New()
	recorder.RealtimeConnectionOpened()
	recorder.ObserveRealtimeConnectionReady(25 * time.Millisecond)
	recorder.RealtimeConnectionClosed()

	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, line := range []string{
		"voice_platform_realtime_connections_active 0",
		"voice_platform_realtime_connections_total 1",
		"voice_platform_realtime_connection_ready_seconds_count 1",
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	for _, value := range []string{"user-1", "vp_session", "connection.ready", "/api/v1/realtime"} {
		if strings.Contains(metrics, value) {
			t.Fatalf("metrics leaked %q: %q", value, metrics)
		}
	}
}

func TestMiddlewarePreservesUpgradeResponseWriterInterfaces(t *testing.T) {
	recorder := New()
	wrapped := recorder.Middleware(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		if _, ok := writer.(http.Hijacker); !ok {
			t.Fatal("wrapped writer lost Hijacker")
		}
		if _, ok := writer.(http.Flusher); !ok {
			t.Fatal("wrapped writer lost Flusher")
		}
		if _, ok := writer.(http.Pusher); !ok {
			t.Fatal("wrapped writer lost Pusher")
		}
		if _, ok := writer.(io.ReaderFrom); !ok {
			t.Fatal("wrapped writer lost ReaderFrom")
		}
		if _, ok := writer.(interface{ Unwrap() http.ResponseWriter }); !ok {
			t.Fatal("wrapped writer lost Unwrap")
		}
	}))
	wrapped.ServeHTTP(&transportWriter{ResponseRecorder: httptest.NewRecorder()}, httptest.NewRequest(http.MethodGet, "/rtc", nil))
}

type transportWriter struct{ *httptest.ResponseRecorder }

func (writer *transportWriter) Flush() {}

func (writer *transportWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) { return nil, nil, nil }

func (writer *transportWriter) Push(string, *http.PushOptions) error { return nil }

func (writer *transportWriter) ReadFrom(source io.Reader) (int64, error) {
	return io.Copy(writer.ResponseRecorder, source)
}
