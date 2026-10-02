package watchconnectedparticipants

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/identity/session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type Lister interface {
	List(context.Context, string) (roster.Result, error)
}

type SessionAuthenticator interface {
	Authenticate(context.Context, string) (auth.Principal, error)
}

const snapshotTimeout = 5 * time.Second
const sessionRevalidationInterval = 10 * time.Second
const heartbeatInterval = 15 * time.Second

// Session validity is rechecked on the live connection, while every snapshot
// independently rechecks channel visibility and active leases.
func NewHandler(lister Lister, notifier *Notifier, authenticator SessionAuthenticator) http.Handler {
	return newHandler(lister, notifier, authenticator, sessionRevalidationInterval, heartbeatInterval)
}

func newHandler(lister Lister, notifier *Notifier, authenticator SessionAuthenticator, revalidateEvery, heartbeatEvery time.Duration) http.Handler {
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
		revalidation := time.NewTicker(revalidateEvery)
		defer revalidation.Stop()
		heartbeat := time.NewTicker(heartbeatEvery)
		defer heartbeat.Stop()
		for {
			select {
			case <-request.Context().Done():
				return
			case <-revalidation.C:
				cookie, err := request.Cookie(session.CookieName)
				if err != nil {
					writeSessionExpired(writer, flusher)
					return
				}
				ctx, cancel := context.WithTimeout(request.Context(), snapshotTimeout)
				current, err := authenticator.Authenticate(ctx, cookie.Value)
				cancel()
				if errors.Is(err, auth.ErrUnauthenticated) || (err == nil && (current.AccountID != principal.AccountID || current.SessionDigest != principal.SessionDigest)) {
					writeSessionExpired(writer, flusher)
					return
				}
				if err != nil {
					return
				}
			case <-heartbeat.C:
				if _, err := fmt.Fprint(writer, ": keepalive\n\n"); err != nil {
					return
				}
				flusher.Flush()
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

func writeSessionExpired(writer http.ResponseWriter, flusher http.Flusher) {
	if _, err := fmt.Fprint(writer, "event: session-expired\ndata: {}\n\n"); err == nil {
		flusher.Flush()
	}
}
