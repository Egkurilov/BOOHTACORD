package httpmetrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRoomServiceMetricsBoundUnknownLabelsAndPublishCalls(t *testing.T) {
	r := New()
	r.ObserveSFURoomServiceCall("ListRooms", false)
	r.ObserveSFURoomServiceCall("private-room-secret", true)
	w := httptest.NewRecorder()
	r.Handler().ServeHTTP(w, httptest.NewRequest("GET", "/metrics", nil))
	text := w.Body.String()
	for _, want := range []string{
		`voice_platform_sfu_room_service_calls_total{method="ListRooms",outcome="success"} 1`,
		`voice_platform_sfu_room_service_calls_total{method="other",outcome="failure"} 1`,
	} {
		if !strings.Contains(text, want) {
			t.Fatal("Missing bounded RoomService metric")
		}
	}
	if strings.Contains(text, "private-room-secret") {
		t.Fatal("Unbounded label")
	}
}
