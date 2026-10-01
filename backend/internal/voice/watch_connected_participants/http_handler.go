package watchconnectedparticipants

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type Lister interface {
	List(context.Context, string) (roster.Result, error)
}

const snapshotTimeout = 5 * time.Second

// Each stream expires quickly so the client's reconnect reauthenticates its
// cookie. Every snapshot rechecks channel visibility and active leases.
func NewHandler(lister Lister, notifier *Notifier) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			http.Error(writer, "session required", http.StatusUnauthorized)
			return
		}
		flusher, ok := writer.(http.Flusher)
		if !ok {
			http.Error(writer, "stream unsupported", http.StatusInternalServerError)
			return
		}
		// Subscribe before loading the initial snapshot so a room change during
		// List is queued and causes a fresh snapshot immediately afterward.
		updates, unsubscribe := notifier.Subscribe()
		defer unsubscribe()
		initialContext, cancelInitial := context.WithTimeout(request.Context(), snapshotTimeout)
		initial, err := lister.List(initialContext, principal.AccountID)
		cancelInitial()
		if err != nil {
			http.Error(writer, "roster unavailable", http.StatusServiceUnavailable)
			return
		}
		writer.Header().Set("Content-Type", "text/event-stream")
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("X-Accel-Buffering", "no")
		write := func(value roster.Result) bool {
			encoded, err := json.Marshal(value)
			if err != nil {
				return false
			}
			if _, err = fmt.Fprintf(writer, "data: %s\n\n", encoded); err != nil {
				return false
			}
			flusher.Flush()
			return true
		}
		if !write(initial) {
			return
		}
		expires := time.NewTimer(10 * time.Second)
		defer expires.Stop()
		for {
			select {
			case <-request.Context().Done():
				return
			case <-expires.C:
				return
			case <-updates:
				ctx, cancel := context.WithTimeout(request.Context(), snapshotTimeout)
				updated, err := lister.List(ctx, principal.AccountID)
				cancel()
				if err != nil || !write(updated) {
					return
				}
			}
		}
	})
}
