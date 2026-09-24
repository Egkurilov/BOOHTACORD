package listtextmessagespostgres

import (
	"context"
	"strings"
	"testing"

	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

func TestAddressedContextKeepsChannelACLAndIncludesAnchor(t *testing.T) {
	database := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{}}
	_, err := New(database).List(context.Background(), listtextmessages.Request{Input: listtextmessages.Input{ChannelID: "channel-1", At: "message-1", Limit: 20}})
	if err != nil || database.arguments[1] != "message-1" || database.arguments[3] != true || !strings.Contains(database.statement, "messages.id = $2::uuid") || !strings.Contains(database.statement, "messages.channel_id = $1") {
		t.Fatalf("statement = %s, arguments = %#v, error = %v", database.statement, database.arguments, err)
	}
	denied := &fakeDatabase{channel: boolRow{value: false}}
	_, err = New(denied).List(context.Background(), listtextmessages.Request{Input: listtextmessages.Input{ChannelID: "channel-1", At: "message-1", Limit: 20}})
	if err != listtextmessages.ErrChannelUnavailable || denied.statement != "" {
		t.Fatalf("unauthorized query = %q, error = %v", denied.statement, err)
	}
}
