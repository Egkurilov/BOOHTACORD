package listtextmessagespostgres

import (
	"context"
	"strings"
	"testing"
	list "voice-platform/backend/internal/chat/list_text_messages"
)

func TestArchiveDataQueryRechecksAccountAndChannelState(t *testing.T) {
	db := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{}}
	_, err := New(db).List(context.Background(), list.Request{Input: list.Input{ActorID: "reader", ChannelID: "channel", Limit: 10, ReadArchive: true}})
	if err != nil {
		t.Fatal(err)
	}
	for _, predicate := range []string{"users.blocked_at IS NULL", "channels.readonly_archive", "channels.archived_at IS NOT NULL"} {
		if !strings.Contains(db.statement, predicate) {
			t.Fatalf("archive data query lacks %s", predicate)
		}
	}
	if len(db.arguments) != 5 || db.arguments[4] != "reader" {
		t.Fatal("archive actor not bound to data query")
	}
}
