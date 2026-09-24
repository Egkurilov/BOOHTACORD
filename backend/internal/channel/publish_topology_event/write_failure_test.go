package publishtopologyevent

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestCommittedMutationPublishesWhenClientWriteFails(t *testing.T) {
	hub := eventhub.New(1)
	client := hub.Subscribe("other-client")
	defer client.Close()
	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"revision":4}`))
	})
	NewHandler(inner, hub).ServeHTTP(&failingWriter{header: make(http.Header)}, httptest.NewRequest(http.MethodPatch, "/", nil))
	select {
	case event := <-client.Events():
		if event.Kind != "channel.updated" || event.Payload["revision"] != int64(4) {
			t.Fatalf("event after failed client write = %#v", event)
		}
	default:
		t.Fatal("committed mutation was not published")
	}
}

type failingWriter struct{ header http.Header }

func (writer *failingWriter) Header() http.Header       { return writer.header }
func (writer *failingWriter) WriteHeader(int)           {}
func (writer *failingWriter) Write([]byte) (int, error) { return 0, errors.New("client disconnected") }
