package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

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
