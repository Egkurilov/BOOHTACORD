package publishtopologyevent

import (
	"bytes"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const maxResponseBytes = 4096

type Publisher interface {
	Publish(eventhub.Event)
}

// NewHandler emits a refresh hint only after the topology command has returned
// a successful response containing its committed revision.
func NewHandler(inner http.Handler, publisher Publisher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		capture := &responseCapture{ResponseWriter: writer}
		inner.ServeHTTP(capture, request)
		if publisher == nil || capture.overflow || (capture.status != http.StatusOK && capture.status != http.StatusCreated) {
			return
		}
		var result struct {
			Revision         int64 `json:"revision"`
			TopologyRevision int64 `json:"topology_revision"`
		}
		if json.Unmarshal(capture.body.Bytes(), &result) != nil {
			return
		}
		revision := result.Revision
		if revision < 1 {
			revision = result.TopologyRevision
		}
		if revision < 1 {
			return
		}
		publisher.Publish(eventhub.Event{
			EventID:    uuid.NewString(),
			Kind:       "channel.updated",
			OccurredAt: time.Now().UTC(),
			Payload:    map[string]any{"revision": revision},
		})
	})
}

type responseCapture struct {
	http.ResponseWriter
	body     bytes.Buffer
	status   int
	overflow bool
}

func (capture *responseCapture) WriteHeader(status int) {
	if capture.status == 0 {
		capture.status = status
	}
	capture.ResponseWriter.WriteHeader(status)
}

func (capture *responseCapture) Write(data []byte) (int, error) {
	if capture.status == 0 {
		capture.status = http.StatusOK
	}
	if !capture.overflow {
		if capture.body.Len()+len(data) > maxResponseBytes {
			capture.overflow = true
		} else {
			_, _ = capture.body.Write(data)
		}
	}
	return capture.ResponseWriter.Write(data)
}
