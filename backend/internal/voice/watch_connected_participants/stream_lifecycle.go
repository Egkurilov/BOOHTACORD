package watchconnectedparticipants

import (
	"context"
	"fmt"
	"net/http"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func serveRosterStream(writer http.ResponseWriter, request *http.Request, flusher http.Flusher, lister Lister, updates <-chan struct{}, authenticator SessionAuthenticator, principal auth.Principal, initial roster.Result, observer FailureObserver, revalidateEvery, heartbeatEvery, reconcileEvery time.Duration) {
	write := newRosterWriter(writer, flusher, initial)
	revalidation := time.NewTicker(revalidateEvery)
	defer revalidation.Stop()
	heartbeat := time.NewTicker(heartbeatEvery)
	defer heartbeat.Stop()
	reconciliation := time.NewTicker(reconcileEvery)
	defer reconciliation.Stop()
	for {
		select {
		case <-request.Context().Done():
			return
		case <-revalidation.C:
			if !revalidateRosterSession(writer, request, flusher, authenticator, principal, observer) {
				return
			}
		case <-heartbeat.C:
			if !writeHeartbeat(writer, flusher) {
				observeFailure(observer, "stream_write")
				return
			}
		case <-updates:
			if !refreshRosterSnapshot(request.Context(), lister, principal.AccountID, write, writer, flusher, observer) {
				return
			}
		case <-reconciliation.C:
			if !refreshRosterSnapshot(request.Context(), lister, principal.AccountID, write, writer, flusher, observer) {
				return
			}
		}
	}
}

func writeHeartbeat(writer http.ResponseWriter, flusher http.Flusher) bool {
	if _, err := fmt.Fprint(writer, ": keepalive\n\n"); err != nil {
		return false
	}
	flusher.Flush()
	return true
}

func revalidateRosterSession(writer http.ResponseWriter, request *http.Request, flusher http.Flusher, authenticator SessionAuthenticator, principal auth.Principal, observer FailureObserver) bool {
	cookie, err := request.Cookie(session.CookieName)
	if err != nil {
		writeSessionExpired(writer, flusher)
		return false
	}
	ctx, cancel := context.WithTimeout(request.Context(), snapshotTimeout)
	current, err := authenticator.Authenticate(ctx, cookie.Value)
	cancel()
	if request.Context().Err() != nil {
		return false
	}
	if authRevoked(err, current, principal) {
		writeSessionExpired(writer, flusher)
		return false
	}
	if err != nil {
		observeFailure(observer, "stream_session_store")
		return false
	}
	return true
}

func writeSessionExpired(writer http.ResponseWriter, flusher http.Flusher) {
	if _, err := fmt.Fprint(writer, "event: session-expired\ndata: {}\n\n"); err == nil {
		flusher.Flush()
	}
}
