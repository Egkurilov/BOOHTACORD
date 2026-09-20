package createpasswordreset

import (
	"context"
	"errors"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/session"
)

func TestCreatePersistsOnlyDigestAndThirtyMinuteExpiry(t *testing.T) {
	now := time.Date(2026, time.September, 17, 10, 0, 0, 0, time.UTC)
	store := &fakeStore{}
	service := New(store, func() time.Time { return now })

	result, err := service.Create(context.Background(), Input{AccountID: "77b14148-7723-4c14-8e69-20a5d9b77972", ActorID: "3ee2a31b-56c8-4361-ad89-5d7582f57062"})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if store.request.AccountID != "77b14148-7723-4c14-8e69-20a5d9b77972" {
		t.Fatalf("stored account ID = %q", store.request.AccountID)
	}
	if store.request.ActorID != "3ee2a31b-56c8-4361-ad89-5d7582f57062" {
		t.Fatalf("stored actor ID = %q", store.request.ActorID)
	}
	if !session.Verify(result.Token, store.request.TokenDigest) {
		t.Fatal("store did not receive the token digest")
	}
	if result.ExpiresAt != now.Add(30*time.Minute) || store.request.ExpiresAt != result.ExpiresAt {
		t.Fatalf("expiry = %v, stored = %v", result.ExpiresAt, store.request.ExpiresAt)
	}
}

func TestCreateDoesNotReturnSecretWhenPersistenceFails(t *testing.T) {
	store := &fakeStore{err: errors.New("database unavailable")}
	result, err := New(store, time.Now).Create(context.Background(), Input{AccountID: "account-1", ActorID: "actor-1"})
	if err == nil || result.Token != "" {
		t.Fatalf("Create() result = %#v, error = %v", result, err)
	}
}

type fakeStore struct {
	request Request
	err     error
}

func (store *fakeStore) Create(_ context.Context, request Request) error {
	store.request = request
	return store.err
}
