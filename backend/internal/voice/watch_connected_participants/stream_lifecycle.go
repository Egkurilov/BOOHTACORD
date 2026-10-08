package watchconnectedparticipants

import (
	"context"
	"net/http"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func serveRosterStream(writer http.ResponseWriter, request *http.Request, flusher http.Flusher, lister Lister, updates <-chan struct{}, authenticator SessionAuthenticator, principal auth.Principal, initial roster.Result, observer FailureObserver, revalidateEvery, heartbeatEvery, reconcileEvery time.Duration) string {
	write := newRosterWriter(writer, flusher, initial)
	writeFailed := false
	checkedWrite := func(value roster.Result) bool { ok := write(value); writeFailed = !ok; return ok }
	revalidation := time.NewTicker(revalidateEvery)
	defer revalidation.Stop()
	heartbeat := time.NewTicker(heartbeatEvery)
	defer heartbeat.Stop()
	reconciliation := time.NewTicker(reconciliationPeriod(reconcileEvery))
	defer reconciliation.Stop()
	for {
		select {
		case <-request.Context().Done():
			return "canceled"
		case <-revalidation.C:
			if reason := revalidateRosterSession(writer, request, flusher, authenticator, principal, observer); reason != "" {
				return reason
			}
		case <-heartbeat.C:
			if !writeHeartbeat(writer, flusher) {
				observeFailure(observer, "stream_write")
				return "write"
			}
		case <-updates:
			if !refreshRosterSnapshot(request.Context(), lister, principal.AccountID, checkedWrite, writer, flusher, observer) {
				return refreshCloseReason(request, writeFailed)
			}
		case <-reconciliation.C:
			if !refreshRosterSnapshot(request.Context(), lister, principal.AccountID, checkedWrite, writer, flusher, observer) {
				return refreshCloseReason(request, writeFailed)
			}
		}
	}
}

func refreshCloseReason(request *http.Request, writeFailed bool) string {
	if request.Context().Err() != nil {
		return "canceled"
	}
	if writeFailed {
		return "write"
	}
	return "snapshot"
}

func writeHeartbeat(writer http.ResponseWriter, flusher http.Flusher) bool {
	return writeStreamFrame(writer, flusher, []byte(": keepalive\n\n")) == nil
}

func revalidateRosterSession(writer http.ResponseWriter, request *http.Request, flusher http.Flusher, authenticator SessionAuthenticator, principal auth.Principal, observer FailureObserver) string {
	cookie, err := request.Cookie(session.CookieName)
	if err != nil {
		writeSessionExpired(writer, flusher)
		return "session_expired"
	}
	ctx, cancel := context.WithTimeout(request.Context(), snapshotTimeout)
	current, err := authenticator.Authenticate(ctx, cookie.Value)
	cancel()
	if request.Context().Err() != nil {
		return "canceled"
	}
	if authRevoked(err, current, principal) {
		writeSessionExpired(writer, flusher)
		return "session_expired"
	}
	if err != nil {
		observeFailure(observer, "stream_session_store")
		return "session_store"
	}
	return ""
}

func writeSessionExpired(writer http.ResponseWriter, flusher http.Flusher) {
	_ = writeStreamFrame(writer, flusher, []byte("event: session-expired\ndata: {}\n\n"))
}
