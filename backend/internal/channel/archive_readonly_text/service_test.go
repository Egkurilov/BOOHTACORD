package archivereadonlytext

import (
	"context"
	"errors"
	"testing"
)

func TestArchiveRequiresConfirmationAndValidRevisionBeforePersistence(t *testing.T) {
	store := &fakeStore{}
	service := New(store)
	input := Input{ActorID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", ExpectedRevision: 1}
	if _, err := service.Archive(t.Context(), input); !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("confirmation err=%v called=%v", err, store.called)
	}
	input.Confirm = true
	if _, err := service.Archive(t.Context(), input); err != nil || !store.called {
		t.Fatalf("valid err=%v called=%v", err, store.called)
	}
}

type fakeStore struct{ called bool }

func (s *fakeStore) Archive(context.Context, Input) (Result, error) {
	s.called = true
	return Result{}, nil
}
