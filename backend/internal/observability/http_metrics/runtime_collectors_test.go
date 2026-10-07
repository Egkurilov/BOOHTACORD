package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPrivateRuntimeCollectorsExposeNumericCapacitySignals(t *testing.T) {
	response := httptest.NewRecorder()
	New().Handler().ServeHTTP(response, httptest.NewRequest("GET", "/metrics", nil))
	text := response.Body.String()
	for _, metric := range []string{"go_goroutines ", "go_memstats_alloc_bytes ", "go_gc_duration_seconds_sum "} {
		if !strings.Contains(text, metric) {
			t.Fatal("missing private runtime metric: " + metric)
		}
	}
	for _, forbidden := range []string{"username=", "session_token=", "password=", "dm_id="} {
		if strings.Contains(text, forbidden) {
			t.Fatal("identity/content label")
		}
	}
}
