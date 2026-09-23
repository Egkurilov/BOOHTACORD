package readmemberavatar

import (
	"context"
	"errors"
	"testing"
)

func TestReadResolvesPrivateKeyThroughMemberRepository(t *testing.T) {
	store, files := &fakeStore{key: "opaque-private-key"}, &fakeFiles{data: []byte("png")}
	data, err := New(store, files).Read(context.Background(), "member-1")
	if err != nil || string(data) != "png" || store.accountID != "member-1" || files.key != store.key { t.Fatalf("Read()=%q,%v store=%#v files=%#v", data, err, store, files) }
}

func TestReadDoesNotReadFilesForMissingOrEmptyMember(t *testing.T) {
	for _, id := range []string{"", "member-1"} {
		store, files := &fakeStore{err: ErrAvatarNotFound}, &fakeFiles{}
		if _, err := New(store, files).Read(context.Background(), id); !errors.Is(err, ErrAvatarNotFound) || files.called { t.Fatalf("Read(%q) error=%v fileRead=%v", id, err, files.called) }
	}
}

type fakeStore struct { key, accountID string; err error }
func (store *fakeStore) FindAvatarKey(_ context.Context, id string) (string, error) { store.accountID = id; return store.key, store.err }
type fakeFiles struct { data []byte; key string; called bool }
func (files *fakeFiles) ReadPNG(_ context.Context, key string) ([]byte, error) { files.key, files.called = key, true; return files.data, nil }
