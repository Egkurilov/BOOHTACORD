package listtextmessagespostgres

import (
	"context"
	"strings"
	"testing"
	list "voice-platform/backend/internal/chat/list_text_messages"
)

func TestForwardUsesExclusiveSameChannelTupleAndAscendingOrder(t *testing.T) {
	db := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{}}
	_, err := New(db).List(context.Background(), list.Request{Input: list.Input{ChannelID: "channel", After: "anchor", Limit: 20}})
	for _, fragment := range []string{"messages.channel_id = $1", "(messages.created_at, messages.id) >", "ORDER BY messages.created_at ASC, messages.id ASC"} {
		if !strings.Contains(db.statement, fragment) {
			t.Fatal("forward query lost scope or tuple order")
		}
	}
	if err != nil || db.arguments[1] != "anchor" || db.arguments[2] != 21 || db.arguments[3] != false {
		t.Fatal("incorrect forward parameters", err)
	}
}
