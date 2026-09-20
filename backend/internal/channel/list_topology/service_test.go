package listtopology

import (
	"context"
	"testing"
)

func TestListReturnsStoreTopologyWithoutMutation(t *testing.T) {
	want := Result{Revision: 3, Categories: []Category{{ID: "category-1", Channels: []Channel{{ID: "channel-1", Kind: "VOICE"}}}}}
	store := &fakeStore{result: want}
	result, err := New(store).List(context.Background())
	if err != nil || result.Revision != 3 || !store.called || result.Categories[0].Channels[0].Kind != "VOICE" {
		t.Fatalf("error = %v, result = %#v, called = %v", err, result, store.called)
	}
}

type fakeStore struct {
	result Result
	called bool
}

func (store *fakeStore) List(context.Context) (Result, error) {
	store.called = true
	return store.result, nil
}
