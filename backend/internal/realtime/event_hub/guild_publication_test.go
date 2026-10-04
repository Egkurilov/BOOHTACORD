package eventhub

import (
	"errors"
	"testing"
	"time"
)

func TestPublishContextReportsCommittedGuildHintJournalFailure(t *testing.T) {
	hub := New(1)
	journal := &fakeJournal{err: errors.New("journal unavailable")}
	hub.SetJournal(journal)
	event := Event{Kind: "guild.profile.updated", OccurredAt: time.Now(), Payload: map[string]any{"revision": int64(2)}}
	if err := hub.PublishContext(t.Context(), event); err == nil || journal.appended != 1 {
		t.Fatal("guild journal error hidden")
	}
}
