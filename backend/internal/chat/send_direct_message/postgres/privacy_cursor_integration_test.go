package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	cursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
	cursorpostgres "voice-platform/backend/internal/chat/advance_direct_message_read_cursor/postgres"
	list "voice-platform/backend/internal/chat/list_direct_messages"
	listpostgres "voice-platform/backend/internal/chat/list_direct_messages/postgres"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMReadCursorAndNavigationCountersStayCallerLocalInPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	sender := send.New(New(NewPoolDatabase(f.pool)))
	message, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "mention", MentionUserIDs: []string{f.peer}})
	if err != nil {
		t.Fatal(err)
	}
	navigation := list.New(listpostgres.New(listpostgres.NewPoolDatabase(f.pool)))
	assertCounters := func(actor string, present bool, unread, mentions int64) {
		t.Helper()
		page, err := navigation.List(ctx, list.Input{ActorID: actor})
		if err != nil {
			t.Fatal(err)
		}
		for _, pair := range page.DirectMessages {
			if pair.ID != f.pair {
				continue
			}
			if !present || pair.UnreadCount != unread || pair.MentionCount != mentions {
				t.Fatalf("incorrect caller-local counters: unread=%d mentions=%d", pair.UnreadCount, pair.MentionCount)
			}
			return
		}
		if present {
			t.Fatal("participant pair absent from navigation")
		}
	}
	assertCounters(f.actor, true, 0, 0)
	assertCounters(f.peer, true, 1, 1)
	assertCounters(f.outsider, false, 0, 0)
	reader := cursor.New(cursorpostgres.New(cursorpostgres.NewPoolDatabase(f.pool)))
	if _, err := reader.Advance(ctx, cursor.Input{ActorID: f.outsider, DirectMessageID: f.pair, MessageID: message.ID}); !errors.Is(err, cursor.ErrDirectMessageUnavailable) {
		t.Fatalf("administrator cursor error=%v", err)
	}
	var foreignCursors int
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM direct_message_read_cursors WHERE account_id=$1 AND direct_message_id=$2`, f.outsider, f.pair).Scan(&foreignCursors); err != nil || foreignCursors != 0 {
		t.Fatalf("foreign cursor count=%d err=%v", foreignCursors, err)
	}
	if _, err := reader.Advance(ctx, cursor.Input{ActorID: f.peer, DirectMessageID: f.pair, MessageID: message.ID}); err != nil {
		t.Fatal(err)
	}
	assertCounters(f.peer, true, 0, 0)
	assertCounters(f.actor, true, 0, 0)
}
