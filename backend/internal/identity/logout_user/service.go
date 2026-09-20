package logoutuser

import (
	"context"
	"crypto/sha256"
	"fmt"

	"voice-platform/backend/internal/identity/session"
)

type Sessions interface {
	Revoke(context.Context, [sha256.Size]byte) error
}

type Service struct {
	sessions Sessions
}

func New(sessions Sessions) Service {
	return Service{sessions: sessions}
}

func (service Service) Logout(context context.Context, token string) error {
	digest, err := session.Digest(token)
	if err != nil {
		return nil
	}
	if err := service.sessions.Revoke(context, digest); err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}
