package listtopology

import (
	"context"
	"testing"
)

func TestListReturnsStoreTopologyWithoutMutation(t *testing.T) {
	want := Result{Revision: 3, Categories: []Category{{ID: "category-1", Channels: []Channel{{ID: "channel-1", Kind: "VOICE"}}}}}
	store := &fakeStore{result: want}
	result, err := New(store).List(context.Background(), Input{ActorID: "actor-1"})
	if err != nil || result.Revision != 3 || !store.called || store.request.ActorID != "actor-1" || result.Categories[0].Channels[0].Kind != "VOICE" {
		t.Fatalf("error = %v, result = %#v, request = %#v", err, result, store.request)
	}
}

type fakeStore struct {
	result  Result
	called  bool
	request Request
}

func (store *fakeStore) List(_ context.Context, request Request) (Result, error) {
	store.called, store.request = true, request
	return store.result, nil
}
