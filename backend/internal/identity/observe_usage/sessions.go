package observeusage

import (
	"context"
	"crypto/sha256"
	auth "voice-platform/backend/internal/identity/authenticate_session"
)

type trackedSessions struct {
	inner   auth.Sessions
	tracker *Tracker
}

func TrackSessions(inner auth.Sessions, tracker *Tracker) auth.Sessions {
	return trackedSessions{inner: inner, tracker: tracker}
}

func (s trackedSessions) FindActive(ctx context.Context, digest [sha256.Size]byte) (auth.Principal, error) {
	principal, err := s.inner.FindActive(ctx, digest)
	if err == nil {
		s.tracker.Record(ctx, principal.AccountID)
	}
	return principal, err
}
