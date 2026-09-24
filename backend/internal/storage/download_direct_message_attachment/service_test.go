package downloaddirectmessageattachment

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	pairID       = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	storageKey   = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestOpenUsesAuthorizedMetadataBeforePrivateFile(t *testing.T) {
	store := &fakeStore{metadata: Metadata{OriginalName: "log.svg", StorageKey: storageKey, SizeBytes: 10}}
	files := &fakeFiles{reader: io.NopCloser(strings.NewReader("safe bytes"))}
	input := Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID}
	opened, err := New(store, files).Open(context.Background(), input)
	if err != nil || store.input != input || files.key != storageKey || files.size != 10 || opened.Reader == nil {
		t.Fatalf("opened=%#v store=%#v files=%#v err=%v", opened.Metadata, store, files, err)
	}
	_ = opened.Reader.Close()
}

func TestOpenHidesUnavailableMetadataWithoutOpeningFile(t *testing.T) {
	store := &fakeStore{err: ErrAttachmentUnavailable}
	files := &fakeFiles{}
	_, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID})
	if !errors.Is(err, ErrAttachmentUnavailable) || files.called {
		t.Fatalf("err=%v files.called=%v", err, files.called)
	}
}

func TestOpenRejectsMalformedInputBeforeDatabaseAndFile(t *testing.T) {
	store, files := &fakeStore{}, &fakeFiles{}
	_, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, DirectMessageID: "bad", AttachmentID: attachmentID})
	if !errors.Is(err, ErrInvalidInput) || store.called || files.called {
		t.Fatalf("err=%v store=%#v files=%#v", err, store, files)
	}
}

func TestOpenHidesMissingFileAfterAuthorization(t *testing.T) {
	store := &fakeStore{metadata: Metadata{OriginalName: "log.svg", StorageKey: storageKey, SizeBytes: 10}}
	files := &fakeFiles{err: ErrFileUnavailable}
	_, err := New(store, files).Open(context.Background(), Input{ActorID: actorID, DirectMessageID: pairID, AttachmentID: attachmentID})
	if !errors.Is(err, ErrAttachmentUnavailable) || !files.called {
		t.Fatalf("err=%v files.called=%v", err, files.called)
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
	called bool
	key    string
	size   int64
	reader io.ReadCloser
	err    error
}

func (files *fakeFiles) Open(key string, size int64) (io.ReadCloser, error) {
	files.called, files.key, files.size = true, key, size
	return files.reader, files.err
}
