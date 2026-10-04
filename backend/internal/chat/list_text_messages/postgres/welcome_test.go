package listtextmessagespostgres

import (
	"testing"
	"time"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

func TestHistoryPreservesSystemWelcomeKind(t *testing.T) {
	database := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{values: [][]any{
		{"message", "channel", "account", "client", "phrase", "", time.Time{}, nil, 1, false, []string{"account"}, []byte("[]"), "SYSTEM_WELCOME"},
	}}}
	messages, err := New(database).List(t.Context(), listtextmessages.Request{Input: listtextmessages.Input{Limit: 10}})
	if err != nil || len(messages) != 1 || messages[0].Kind != "SYSTEM_WELCOME" {
		t.Fatal("history lost welcome kind")
	}
}
