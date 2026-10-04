package searchmessagespostgres

import (
	"testing"
	"time"
	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestUnifiedSearchSeparatesConversationAndMessageKinds(t *testing.T) {
	db := &fakeDatabase{rows: &fakeRows{values: [][]any{{"CHANNEL", "message", "channel", "", "account", "phrase", time.Time{}, nil, 1, "SYSTEM_WELCOME"}}}}
	messages, err := New(db).Search(t.Context(), searchmessages.Request{Limit: 10})
	if err != nil || len(messages) != 1 || messages[0].Kind != "CHANNEL" || messages[0].MessageKind != "SYSTEM_WELCOME" {
		t.Fatal("search changed conversation kind or lost message kind")
	}
}
