package authenticatesession

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/session"
)

var (
	ErrUnauthenticated = errors.New("unauthenticated")
	ErrSessionNotFound = errors.New("active session not found")
)

type Principal struct {
	AccountID     string
	Role          string
	SessionDigest [sha256.Size]byte
}

type Sessions interface {
	FindActive(context.Context, [sha256.Size]byte) (Principal, error)
}

type Service struct {
	sessions Sessions
}

func New(sessions Sessions) Service {
	return Service{sessions: sessions}
}

func (service Service) Authenticate(context context.Context, token string) (Principal, error) {
	digest, err := session.Digest(token)
	if err != nil {
		return Principal{}, ErrUnauthenticated
	}
	principal, err := service.sessions.FindActive(context, digest)
	if errors.Is(err, ErrSessionNotFound) {
		return Principal{}, ErrUnauthenticated
	}
	if err != nil {
		return Principal{}, fmt.Errorf("find active session: %w", err)
	}
	principal.SessionDigest = digest
	return principal, nil
}
