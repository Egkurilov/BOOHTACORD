package watchconnectedparticipants

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type rosterWrite func(roster.Result) bool

func newRosterWriter(writer http.ResponseWriter, flusher http.Flusher, initial roster.Result) rosterWrite {
	encoded, _ := json.Marshal(initial)
	return func(value roster.Result) bool {
		updated, err := json.Marshal(value)
		if err != nil {
			return false
		}
		if bytes.Equal(updated, encoded) {
			return true
		}
		if err := writeRosterBytes(writer, flusher, updated); err != nil {
			return false
		}
		encoded = updated
		return true
	}
}

func writeRoster(writer http.ResponseWriter, flusher http.Flusher, value roster.Result) bool {
	encoded, err := json.Marshal(value)
	return err == nil && writeRosterBytes(writer, flusher, encoded) == nil
}

func writeRosterBytes(writer http.ResponseWriter, flusher http.Flusher, encoded []byte) error {
	return writeStreamFrame(writer, flusher, []byte(fmt.Sprintf("data: %s\n\n", encoded)))
}

func refreshRosterSnapshot(parent context.Context, lister Lister, accountID string, write rosterWrite, writer http.ResponseWriter, flusher http.Flusher, observer FailureObserver) bool {
	ctx, cancel := context.WithTimeout(parent, snapshotTimeout)
	updated, err := loadRefresh(ctx, lister, accountID)
	cancel()
	if err != nil {
		if errors.Is(parent.Err(), context.Canceled) {
			return false
		}
		observeFailure(observer, "stream_snapshot")
		traceFailure(parent, err)
		if !writeRosterUnavailable(writer, flusher) {
			observeFailure(observer, "stream_write")
		}
		return false
	}
	if !write(updated) {
		observeFailure(observer, "stream_write")
		return false
	}
	observeSuccess(observer)
	return true
}

func writeRosterUnavailable(writer http.ResponseWriter, flusher http.Flusher) bool {
	return writeStreamFrame(writer, flusher, []byte("event: roster-unavailable\ndata: {}\n\n")) == nil
}

func authRevoked(err error, current, principal auth.Principal) bool {
	return errors.Is(err, auth.ErrUnauthenticated) || (err == nil && (current.AccountID != principal.AccountID || current.SessionDigest != principal.SessionDigest))
}
