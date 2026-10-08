package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRosterStreamFailureStagesAreBounded(t *testing.T) {
	recorder := New()
	for _, stage := range []string{"stream_snapshot", "stream_session_store", "stream_write", "presence_validation", "presence_token", "presence_room_list", "presence_participants", "presence_snapshot_timeout"} {
		recorder.ObserveVoiceRosterFailure(stage)
	}
	response := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	for _, stage := range []string{"stream_snapshot", "stream_session_store", "stream_write"} {
		if !strings.Contains(response.Body.String(), `stage="`+stage+`"} 1`) {
			t.Fatalf("missing bounded roster stage %q", stage)
		}
	}
}
