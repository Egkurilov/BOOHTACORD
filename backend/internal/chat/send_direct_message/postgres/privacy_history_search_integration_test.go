package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	history "voice-platform/backend/internal/chat/list_direct_message_history"
	historypostgres "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	search "voice-platform/backend/internal/chat/search_direct_message_history"
	searchpostgres "voice-platform/backend/internal/chat/search_direct_message_history/postgres"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMHistorySearchAndReplyShareParticipantACLInPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	sender := send.New(New(NewPoolDatabase(f.pool)))
	original, err := sender.Send(ctx, send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "privacyfixture"})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := sender.Send(ctx, send.Input{ActorID: f.peer, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), ReplyToID: original.ID, Body: "replyfixture"})
	if err != nil {
		t.Fatal(err)
	}
	read := history.New(historypostgres.New(historypostgres.NewPoolDatabase(f.pool)))
	find := search.New(searchpostgres.New(searchpostgres.NewPoolDatabase(f.pool)))
	for _, actor := range []string{f.actor, f.peer} {
		page, err := read.List(ctx, history.Input{ActorID: actor, DirectMessageID: f.pair, Limit: 10})
		if err != nil || len(page.Messages) != 2 || page.Messages[0].ID != reply.ID || page.Messages[0].ReplyPreview == nil || page.Messages[0].ReplyPreview.ID != original.ID {
			t.Fatalf("participant history failed: count=%d err=%v", len(page.Messages), err)
		}
		matches, err := find.Search(ctx, search.Input{ActorID: actor, DirectMessageID: f.pair, Query: "privacyfixture", Limit: 10})
		if err != nil || len(matches.Messages) != 1 || matches.Messages[0].ID != original.ID {
			t.Fatalf("participant search failed: count=%d err=%v", len(matches.Messages), err)
		}
	}
	if _, err := read.List(ctx, history.Input{ActorID: f.outsider, DirectMessageID: f.pair, Limit: 10}); !errors.Is(err, history.ErrDirectMessageUnavailable) {
		t.Fatalf("administrator history error=%v", err)
	}
	if _, err := find.Search(ctx, search.Input{ActorID: f.outsider, DirectMessageID: f.pair, Query: "privacyfixture", Limit: 10}); !errors.Is(err, search.ErrDirectMessageUnavailable) {
		t.Fatalf("administrator search error=%v", err)
	}
	foreignClientID := uuid.NewString()
	if _, err := sender.Send(ctx, send.Input{ActorID: f.outsider, DirectMessageID: f.pair, ClientMessageID: foreignClientID, ReplyToID: original.ID, Body: "foreign"}); !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("administrator reply error=%v", err)
	}
	assertDMMessageCount(t, f, foreignClientID, 0)
	if _, err := f.pool.Exec(ctx, `UPDATE direct_message_messages SET body='',deleted_at=now() WHERE id=$1`, original.ID); err != nil {
		t.Fatal(err)
	}
	page, err := read.List(ctx, history.Input{ActorID: f.peer, DirectMessageID: f.pair, Limit: 10})
	if err != nil || len(page.Messages) != 2 || !page.Messages[1].Deleted || page.Messages[1].Body != "" || page.Messages[0].ReplyPreview == nil || !page.Messages[0].ReplyPreview.Deleted {
		t.Fatalf("deleted history state failed: count=%d err=%v", len(page.Messages), err)
	}
	matches, err := find.Search(ctx, search.Input{ActorID: f.peer, DirectMessageID: f.pair, Query: "privacyfixture", Limit: 10})
	if err != nil || len(matches.Messages) != 0 {
		t.Fatalf("deleted search state failed: count=%d err=%v", len(matches.Messages), err)
	}
}
