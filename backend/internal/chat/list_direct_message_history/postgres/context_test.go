package listdirectmessagehistorypostgres

import (
	"context"
	"strings"
	"testing"

	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
)

func TestAddressedContextKeepsParticipantACLAndIncludesAnchor(t *testing.T) {
	database := &fakeDatabase{available: boolRow{value: true}, rows: &fakeRows{}}
	_, err := New(database).List(context.Background(), listdirectmessagehistory.Request{Input: listdirectmessagehistory.Input{ActorID: actorID, DirectMessageID: directMessageID, At: actorID, Limit: 20}})
	if err != nil || database.arguments[2] != actorID || database.arguments[4] != true || !strings.Contains(database.statement, "m.id = $3::uuid") || !strings.Contains(database.statement, "(SELECT id FROM readable_pair)") {
		t.Fatalf("statement = %s, arguments = %#v, error = %v", database.statement, database.arguments, err)
	}
	denied := &fakeDatabase{available: boolRow{value: false}}
	_, err = New(denied).List(context.Background(), listdirectmessagehistory.Request{Input: listdirectmessagehistory.Input{ActorID: actorID, DirectMessageID: directMessageID, At: actorID, Limit: 20}})
	if err != listdirectmessagehistory.ErrDirectMessageUnavailable || denied.statement != "" {
		t.Fatalf("unauthorized query = %q, error = %v", denied.statement, err)
	}
}
