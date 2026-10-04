package observeusage

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
)

type sessionStub struct{ err error }

func (s sessionStub) FindActive(context.Context, [sha256.Size]byte) (auth.Principal, error) {
	return auth.Principal{AccountID: "private-account"}, s.err
}

func TestSessionsOnlyTrackSuccessfulAuthenticationAndPreserveResults(t *testing.T) {
	store := &fakeStore{err: errors.New("metrics storage failure")}
	tracker := NewTracker(store, time.Now)
	principal, err := TrackSessions(sessionStub{}, tracker).FindActive(context.Background(), [sha256.Size]byte{})
	if err != nil || principal.AccountID != "private-account" || len(store.writes) != 1 {
		t.Fatal("metrics failure changed authentication")
	}
	_, err = TrackSessions(sessionStub{err: auth.ErrSessionNotFound}, tracker).FindActive(context.Background(), [sha256.Size]byte{})
	if !errors.Is(err, auth.ErrSessionNotFound) || len(store.writes) != 1 {
		t.Fatal("invalid session recorded")
	}
}
