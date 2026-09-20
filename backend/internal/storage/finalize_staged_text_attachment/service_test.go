package finalizestagedtextattachment

import (
	"context"
	"errors"
	"testing"
)

const (
	actorID   = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	channelID = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestFinalizeMovesThenPersistsPrivateUnattachedMetadata(t *testing.T) {
	mover, store := &fakeMover{}, &fakeStore{}
	result, err := New(store, mover).Finalize(context.Background(), Input{
		ActorID: actorID, ChannelID: channelID, TempPath: "stage/upload.part", OriginalName: "image.png", SizeBytes: 5,
	})
	if err != nil || !mover.moved || !store.called || result.ID != store.request.ID || result.StorageKey != store.request.StorageKey {
		t.Fatalf("result = %#v, mover = %#v, store = %#v, error = %v", result, mover, store, err)
	}
	if !validUUID(store.request.ID) || !validUUID(store.request.StorageKey) || store.request.ID == store.request.StorageKey {
		t.Fatalf("request = %#v", store.request)
	}
}

func TestFinalizeRemovesMovedObjectWhenTargetChangedAfterStaging(t *testing.T) {
	mover := &fakeMover{}
	_, err := New(&fakeStore{err: ErrTargetUnavailable}, mover).Finalize(context.Background(), standardInput())
	if !errors.Is(err, ErrTargetUnavailable) || !mover.removed || mover.removedKey != mover.storageKey {
		t.Fatalf("mover = %#v, error = %v", mover, err)
	}
}

func TestFinalizeRejectsInvalidValuesBeforeMoving(t *testing.T) {
	for _, input := range []Input{
		{ActorID: "invalid", ChannelID: channelID, TempPath: "stage/upload.part", OriginalName: "x", SizeBytes: 1},
		{ActorID: actorID, ChannelID: channelID, TempPath: "", OriginalName: "x", SizeBytes: 1},
		{ActorID: actorID, ChannelID: channelID, TempPath: "stage/upload.part", OriginalName: "\x00", SizeBytes: 1},
		{ActorID: actorID, ChannelID: channelID, TempPath: "stage/upload.part", OriginalName: "x", SizeBytes: MaxAttachmentBytes + 1},
	} {
		mover := &fakeMover{}
		_, err := New(&fakeStore{}, mover).Finalize(context.Background(), input)
		if !errors.Is(err, ErrInvalidInput) || mover.moved {
			t.Fatalf("input = %#v, mover = %#v, error = %v", input, mover, err)
		}
	}
}

func standardInput() Input {
	return Input{ActorID: actorID, ChannelID: channelID, TempPath: "stage/upload.part", OriginalName: "x", SizeBytes: 1}
}
