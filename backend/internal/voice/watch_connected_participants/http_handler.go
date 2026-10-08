package watchconnectedparticipants

import (
	"context"
	"net/http"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type Lister interface {
	List(context.Context, string) (roster.Result, error)
}

type SessionAuthenticator interface {
	Authenticate(context.Context, string) (auth.Principal, error)
}

type FailureObserver interface {
	ObserveVoiceRosterFailure(string)
}

const snapshotTimeout = 5 * time.Second
const sessionRevalidationInterval = 10 * time.Second
const heartbeatInterval = 15 * time.Second
const rosterReconciliationInterval = 5 * time.Second

// Session validity is rechecked on the live connection, while every snapshot
// independently rechecks channel visibility and active leases.
func NewHandler(lister Lister, notifier *Notifier, authenticator SessionAuthenticator, observers ...FailureObserver) http.Handler {
	return newHandler(lister, notifier, authenticator, sessionRevalidationInterval, heartbeatInterval, rosterReconciliationInterval, observers...)
}

func newHandler(lister Lister, notifier *Notifier, authenticator SessionAuthenticator, revalidateEvery, heartbeatEvery, reconcileEvery time.Duration, observers ...FailureObserver) http.Handler {
	var observer FailureObserver
	if len(observers) > 0 {
		observer = observers[0]
	}
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
		// Subscribe first so updates during the initial fetch are not lost.
		updates, unsubscribe := notifier.Subscribe()
		defer unsubscribe()
		ctx, cancel := context.WithTimeout(request.Context(), snapshotTimeout)
		started := time.Now()
		initial, err := lister.List(ctx, principal.AccountID)
		observeInitial(observer, request.Context(), time.Since(started), err)
		cancel()
		if err != nil {
			if request.Context().Err() != nil {
				return
			}
			writeInitialFailure(writer, err)
			return
		}
		writeSSEHeaders(writer)
		if !writeRoster(writer, flusher, initial) {
			observeFailure(observer, "stream_write")
			return
		}
		closeStream := observeStream(observer)
		observeSuccess(observer)
		reason := "other"
		defer func() { closeStream(reason) }()
		reason = serveRosterStream(writer, request, flusher, lister, updates, authenticator, principal, initial, observer, revalidateEvery, heartbeatEvery, reconcileEvery)
	})
}

func writeSSEHeaders(writer http.ResponseWriter) {
	writer.Header().Set("Content-Type", "text/event-stream")
	writer.Header().Set("Cache-Control", "no-store")
	writer.Header().Set("X-Accel-Buffering", "no")
}

func observeFailure(observer FailureObserver, stage string) {
	if observer != nil {
		observer.ObserveVoiceRosterFailure(stage)
	}
}
