package downloadtextattachment

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	channelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	storageKey   = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestOpenReadsOnlyMetadataAuthorizedForCurrentActorAndChannel(t *testing.T) {
	store := &fakeStore{metadata: Metadata{OriginalName: "game-log.svg", StorageKey: storageKey, SizeBytes: 10}}
	files := &fakeFiles{reader: io.NopCloser(strings.NewReader("safe bytes"))}
	opened, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
	if err != nil || !store.called || files.key != storageKey || files.expectedSize != 10 || opened.Metadata.OriginalName != "game-log.svg" || opened.Reader == nil {
		t.Fatalf("opened = %#v, store called = %v, file key = %q, size = %d, error = %v", opened.Metadata, store.called, files.key, files.expectedSize, err)
	}
	_ = opened.Reader.Close()
}

func TestOpenDoesNotTouchPrivateStorageWhenAttachmentIsUnavailable(t *testing.T) {
	store := &fakeStore{err: ErrAttachmentUnavailable}
	files := &fakeFiles{}
	_, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
	if !errors.Is(err, ErrAttachmentUnavailable) || !store.called || files.called {
		t.Fatalf("store called = %v, files called = %v, error = %v", store.called, files.called, err)
	}
}

func TestOpenRejectsMalformedIdentifiersBeforeStoreOrStorage(t *testing.T) {
	store := &fakeStore{}
	files := &fakeFiles{}
	_, err := New(store, files).Open(context.Background(), Input{ActorID: "invalid", ChannelID: channelID, AttachmentID: attachmentID})
	if !errors.Is(err, ErrInvalidInput) || store.called || files.called {
		t.Fatalf("store called = %v, files called = %v, error = %v", store.called, files.called, err)
	}
}

type fakeStore struct {
	called   bool
	input    Input
	metadata Metadata
	err      error
}

func (store *fakeStore) Find(_ context.Context, input Input) (Metadata, error) {
	store.called, store.input = true, input
	return store.metadata, store.err
}

type fakeFiles struct {
	called       bool
	key          string
	expectedSize int64
	reader       io.ReadCloser
	err          error
}

func (files *fakeFiles) Open(key string, expectedSize int64) (io.ReadCloser, error) {
	files.called, files.key, files.expectedSize = true, key, expectedSize
	return files.reader, files.err
}
