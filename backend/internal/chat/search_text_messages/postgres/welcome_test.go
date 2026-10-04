package searchtextmessagespostgres

import (
	"testing"
	"time"
	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
)

func TestSearchPreservesWelcomeKind(t *testing.T) {
	db := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{values: [][]any{{"message", "channel", "account", "phrase", time.Time{}, nil, 1, "SYSTEM_WELCOME"}}}}
	messages, err := New(db).Search(t.Context(), searchtextmessages.Request{Input: searchtextmessages.Input{Limit: 10}})
	if err != nil || len(messages) != 1 || messages[0].Kind != "SYSTEM_WELCOME" {
		t.Fatal("search lost welcome kind")
	}
}
