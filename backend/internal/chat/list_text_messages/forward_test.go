package listtextmessages

import (
	"context"
	"testing"
)

func TestForwardRejectsAmbiguousCursorsAndPreservesAscendingLookahead(t *testing.T) {
	for _, input := range []Input{{ChannelID: channelID, After: "bad", Limit: 20}, {ChannelID: channelID, After: attachmentID, Before: attachmentID, Limit: 20}, {ChannelID: channelID, After: attachmentID, At: attachmentID, Limit: 20}} {
		store := &fakeStore{}
		if _, err := New(store).List(context.Background(), input); err != ErrInvalidInput || store.called {
			t.Fatal("ambiguous cursor reached store")
		}
	}
	store := &fakeStore{messages: []Message{{ID: "one"}, {ID: "two"}, {ID: "three"}}}
	result, err := New(store).List(context.Background(), Input{ChannelID: channelID, After: attachmentID, Limit: 2})
	if err != nil || store.request.After != attachmentID || result.NextCursor != "two" {
		t.Fatal(result, err)
	}
}
