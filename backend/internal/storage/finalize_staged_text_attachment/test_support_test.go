package finalizestagedtextattachment

import "context"

type fakeMover struct {
	moved, removed bool
	storageKey     string
	removedKey     string
}

func (mover *fakeMover) Move(_ string, key string) error {
	mover.moved, mover.storageKey = true, key
	return nil
}

func (mover *fakeMover) Remove(key string) error {
	mover.removed, mover.removedKey = true, key
	return nil
}

type fakeStore struct {
	called  bool
	request Request
	err     error
}

func (store *fakeStore) Create(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	if store.err != nil {
		return Result{}, store.err
	}
	return Result{ID: request.ID, OwnerID: request.ActorID, ChannelID: request.ChannelID, OriginalName: request.OriginalName, StorageKey: request.StorageKey, SizeBytes: request.SizeBytes}, nil
}
