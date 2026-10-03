package publishpermissionevent

import (
	"bytes"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Publisher interface{ Publish(eventhub.Event) }

func NewHandler(inner http.Handler, publisher Publisher) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		capture := &responseCapture{ResponseWriter: writer}
		inner.ServeHTTP(capture, request)
		if publisher == nil || capture.status < 200 || capture.status >= 300 {
			return
		}
		var result struct {
			Role     string `json:"role"`
			Revision int64  `json:"revision"`
		}
		if json.Unmarshal(capture.body.Bytes(), &result) != nil || result.Role != "MEMBER" || result.Revision < 1 {
			return
		}
		publisher.Publish(eventhub.Event{EventID: uuid.NewString(), Kind: "role.permissions.updated", OccurredAt: time.Now().UTC(), Payload: map[string]any{"role": "MEMBER", "revision": result.Revision}})
	})
}

type responseCapture struct {
	http.ResponseWriter
	body   bytes.Buffer
	status int
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
	_, _ = capture.body.Write(data)
	return capture.ResponseWriter.Write(data)
}
