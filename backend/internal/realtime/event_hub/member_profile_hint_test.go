package eventhub

import (
	"context"
	"testing"
	"time"
)

func TestMemberProfileHintIsJournaledAndBroadcast(t *testing.T) {
	hub := New(1)
	journal := &fakeJournal{}
	hub.SetJournal(journal)
	sub := hub.Subscribe("33333333-3333-4333-8333-333333333333")
	defer sub.Close()
	event := Event{EventID: "11111111-1111-4111-8111-111111111111", Kind: "member.profile.updated", OccurredAt: time.Now(), Payload: map[string]any{"user_id": "22222222-2222-4222-8222-222222222222", "revision": int64(3)}}
	if err := hub.PublishContext(context.Background(), event); err != nil {
		t.Fatal(err)
	}
	if journal.appended != 1 || len(journal.recipients) != 0 {
		t.Fatalf("profile hint journal = %#v", journal)
	}
	select {
	case delivered := <-sub.Events():
		if delivered.Kind != event.Kind || delivered.Payload["revision"] != int64(3) {
			t.Fatalf("delivered = %#v", delivered)
		}
	default:
		t.Fatal("profile hint was not broadcast")
	}
}
