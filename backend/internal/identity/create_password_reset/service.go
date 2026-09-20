package createpasswordreset

import (
	"context"
	"crypto/sha256"
	"fmt"
	"time"

	"voice-platform/backend/internal/identity/session"
)

const lifetime = 30 * time.Minute

type Input struct {
	AccountID string
	ActorID   string
}

type Request struct {
	AccountID   string
	ActorID     string
	TokenDigest [sha256.Size]byte
	ExpiresAt   time.Time
}

type Store interface {
	Create(context.Context, Request) error
}

type Result struct {
	Token     string
	ExpiresAt time.Time
}

type Service struct {
	store Store
	now   func() time.Time
}

func New(store Store, now func() time.Time) Service {
	return Service{store: store, now: now}
}

func (service Service) Create(context context.Context, input Input) (Result, error) {
	issued, err := session.Issue()
	if err != nil {
		return Result{}, fmt.Errorf("issue reset secret: %w", err)
	}
	expiresAt := service.now().Add(lifetime)
	request := Request{AccountID: input.AccountID, ActorID: input.ActorID, TokenDigest: issued.Digest, ExpiresAt: expiresAt}
	if err := service.store.Create(context, request); err != nil {
		return Result{}, fmt.Errorf("persist password reset: %w", err)
	}
	return Result{Token: issued.Token, ExpiresAt: expiresAt}, nil
}
