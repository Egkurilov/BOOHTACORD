package publishtopologyevent

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestPublishesUnifiedMutationTopologyRevision(t *testing.T) {
	hub := eventhub.New(1)
	subscriber := hub.Subscribe("client")
	defer subscriber.Close()
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusAccepted)
		_, _ = fmt.Fprint(w, `{"topology_revision":9,"result":{"resource_id":"id"}}`)
	})
	NewHandler(inner, hub).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/", nil))
	select {
	case event := <-subscriber.Events():
		if event.Payload["revision"] != int64(9) {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("missing topology event")
	}
}
