package maintenanceadmissionapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const (
	maintenanceSnapshotTimeout = 3 * time.Second
	maintenancePollInterval    = 5 * time.Second
	maintenanceHeartbeat       = 15 * time.Second
)

// NewEventHandler streams the public maintenance flag to guests and signed-in
// clients. The periodic read keeps changes made by the server-local operator
// command visible without exposing any operator metadata.
func NewEventHandler(reader StateReader) http.Handler {
	return newEventHandler(reader, maintenancePollInterval, maintenanceHeartbeat)
}

func newEventHandler(reader StateReader, pollEvery, heartbeatEvery time.Duration) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		flusher, ok := writer.(http.Flusher)
		if !ok {
			http.Error(writer, "stream unsupported", http.StatusInternalServerError)
			return
		}
		active, err := readActive(request.Context(), reader)
		if err != nil {
			http.Error(writer, "maintenance unavailable", http.StatusServiceUnavailable)
			return
		}

		writer.Header().Set("Content-Type", "text/event-stream")
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("X-Accel-Buffering", "no")
		hasWrittenState := false
		write := func(state bool) bool {
			if state == active && hasWrittenState {
				return true
			}
			encoded, err := json.Marshal(struct {
				Active bool `json:"active"`
			}{Active: state})
			if err != nil {
				return false
			}
			if _, err := fmt.Fprintf(writer, "data: %s\n\n", encoded); err != nil {
				return false
			}
			flusher.Flush()
			active, hasWrittenState = state, true
			return true
		}
		if !write(active) {
			return
		}

		poll := time.NewTicker(pollEvery)
		defer poll.Stop()
		heartbeat := time.NewTicker(heartbeatEvery)
		defer heartbeat.Stop()
		for {
			select {
			case <-request.Context().Done():
				return
			case <-poll.C:
				state, err := readActive(request.Context(), reader)
				if err != nil {
					continue
				}
				if !write(state) {
					return
				}
			case <-heartbeat.C:
				if _, err := fmt.Fprint(writer, ": keepalive\n\n"); err != nil {
					return
				}
				flusher.Flush()
			}
		}
	})
}

func readActive(parent context.Context, reader StateReader) (bool, error) {
	ctx, cancel := context.WithTimeout(parent, maintenanceSnapshotTimeout)
	defer cancel()
	return reader.Active(ctx)
}
