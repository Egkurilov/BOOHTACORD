package authorizedirectmessageattachment

import (
	"context"
	"errors"
	"testing"
)

const actorID = "11111111-1111-4111-8111-111111111111"
const pairID = "22222222-2222-4222-8222-222222222222"

func TestAuthorizeRejectsMalformedIdentifiersBeforeStore(t *testing.T) {
	store := &fakeStore{}
	if err := New(store).Authorize(context.Background(), Input{ActorID: actorID, DirectMessageID: "not-uuid"}); !errors.Is(err, ErrInvalidInput) || store.called {
		t.Fatalf("error=%v called=%v", err, store.called)
	}
}

func TestAuthorizePassesPairIdentityAndMasksMissingPair(t *testing.T) {
	store := &fakeStore{err: ErrTargetUnavailable}
	err := New(store).Authorize(context.Background(), Input{ActorID: actorID, DirectMessageID: pairID})
	if !errors.Is(err, ErrTargetUnavailable) || store.input.DirectMessageID != pairID || store.input.ActorID != actorID {
		t.Fatalf("error=%v input=%#v", err, store.input)
	}
}

type fakeStore struct {
	called bool
	input  Input
	err    error
}

func (store *fakeStore) Authorize(_ context.Context, input Input) error {
	store.called, store.input = true, input
	return store.err
}
