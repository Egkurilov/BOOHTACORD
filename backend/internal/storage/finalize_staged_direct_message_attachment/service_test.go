package finalizestageddirectmessageattachment

import (
	"context"
	"errors"
	"testing"
)

func TestFinalizeMovesPrivateFileAndPersistsPairTarget(t *testing.T) {
	store, mover := &fakeStore{}, &fakeMover{}
	service := New(store, mover)
	result, err := service.Finalize(context.Background(), Input{ActorID: "11111111-1111-4111-8111-111111111111", DirectMessageID: "22222222-2222-4222-8222-222222222222", TempPath: "staged", OriginalName: "a.png", SizeBytes: 42})
	if err != nil || store.request.DirectMessageID != "22222222-2222-4222-8222-222222222222" || mover.movedKey == "" || result.ID != store.request.ID {
		t.Fatalf("result=%#v request=%#v mover=%#v error=%v", result, store.request, mover, err)
	}
}

func TestFinalizeRollsBackMovedFileAfterPairRevocation(t *testing.T) {
	store, mover := &fakeStore{err: ErrTargetUnavailable}, &fakeMover{}
	_, err := New(store, mover).Finalize(context.Background(), Input{ActorID: "11111111-1111-4111-8111-111111111111", DirectMessageID: "22222222-2222-4222-8222-222222222222", TempPath: "staged", OriginalName: "a.png", SizeBytes: 1})
	if !errors.Is(err, ErrTargetUnavailable) || mover.removedKey != mover.movedKey || mover.removedKey == "" {
		t.Fatalf("error=%v mover=%#v", err, mover)
	}
}

type fakeStore struct {
	request Request
	err     error
}

func (store *fakeStore) Create(_ context.Context, request Request) (Result, error) {
	store.request = request
	return Result{ID: request.ID, OwnerID: request.ActorID, DirectMessageID: request.DirectMessageID, OriginalName: request.OriginalName, StorageKey: request.StorageKey, SizeBytes: request.SizeBytes}, store.err
}

type fakeMover struct{ movedKey, removedKey string }

func (mover *fakeMover) Move(_, key string) error { mover.movedKey = key; return nil }
func (mover *fakeMover) Remove(key string) error  { mover.removedKey = key; return nil }
