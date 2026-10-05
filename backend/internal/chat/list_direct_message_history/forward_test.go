package listdirectmessagehistory

import (
	"context"
	"testing"
)

func TestForwardRejectsAmbiguousCursorsAndPreservesAscendingLookahead(t *testing.T) {
	for _, input := range []Input{{ActorID: historyActorID, DirectMessageID: historyDirectMessageID, After: "bad", Limit: 20}, {ActorID: historyActorID, DirectMessageID: historyDirectMessageID, After: historyActorID, At: historyActorID, Limit: 20}} {
		store := &fakeStore{}
		if _, err := New(store).List(context.Background(), input); err != ErrInvalidInput || store.called {
			t.Fatal("ambiguous cursor reached store")
		}
	}
	store := &fakeStore{messages: []Message{{ID: "one"}, {ID: "two"}, {ID: "three"}}}
	result, err := New(store).List(context.Background(), Input{ActorID: historyActorID, DirectMessageID: historyDirectMessageID, After: historyActorID, Limit: 2})
	if err != nil || store.request.After != historyActorID || result.NextCursor != "two" {
		t.Fatal(result, err)
	}
}
