package dispatchvoicesfurevocation

import (
	"context"
	"errors"
	"testing"

	removelivekitparticipant "voice-platform/backend/internal/media/remove_livekit_participant"
)

func TestDispatchConfirmsRemovedOrAlreadyAbsentParticipant(t *testing.T) {
	for name, removeError := range map[string]error{
		"removed": nil,
		"absent":  removelivekitparticipant.ErrParticipantAbsent,
	} {
		t.Run(name, func(t *testing.T) {
			store := &fakeStore{items: []Item{testItem}}
			result, err := New(store, removerFunc(func(context.Context, string, string) error { return removeError })).Dispatch(context.Background(), 1)
			if err != nil || result.Confirmed != 1 || len(store.confirmed) != 1 || len(store.retried) != 0 {
				t.Fatalf("result = %#v, error = %v, store = %#v", result, err, store)
			}
		})
	}
}

func TestDispatchRecordsTruthfulPendingResultWhenRoomServiceUnavailable(t *testing.T) {
	store := &fakeStore{items: []Item{testItem}}
	result, err := New(store, removerFunc(func(context.Context, string, string) error { return removelivekitparticipant.ErrRoomServiceUnavailable })).Dispatch(context.Background(), 1)
	if !errors.Is(err, ErrPending) || result.Pending != 1 || len(store.confirmed) != 0 || len(store.retried) != 1 || store.retried[0].code != "SFU_UNAVAILABLE" {
		t.Fatalf("result = %#v, error = %v, store = %#v", result, err, store)
	}
}

var testItem = Item{LeaseID: "11111111-1111-4111-8111-111111111111", ChannelID: "22222222-2222-4222-8222-222222222222", ClaimToken: "33333333-3333-4333-8333-333333333333"}

type fakeStore struct {
	items     []Item
	confirmed []Item
	retried   []retry
}

func (store *fakeStore) Claim(context.Context, int) ([]Item, error) { return store.items, nil }
func (store *fakeStore) Confirm(_ context.Context, item Item) error {
	store.confirmed = append(store.confirmed, item)
	return nil
}
func (store *fakeStore) Retry(_ context.Context, item Item, code string) error {
	store.retried = append(store.retried, retry{item, code})
	return nil
}

type retry struct {
	item Item
	code string
}

type removerFunc func(context.Context, string, string) error

func (function removerFunc) Remove(context context.Context, leaseID, channelID string) error {
	return function(context, leaseID, channelID)
}
