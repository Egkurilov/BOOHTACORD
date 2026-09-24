package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	edit "voice-platform/backend/internal/chat/edit_direct_message"
	editpostgres "voice-platform/backend/internal/chat/edit_direct_message/postgres"
	history "voice-platform/backend/internal/chat/list_direct_message_history"
	historypostgres "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	list "voice-platform/backend/internal/chat/list_direct_messages"
	listpostgres "voice-platform/backend/internal/chat/list_direct_messages/postgres"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMMentionIsPrivateAndFollowsEditDeleteAndCursor(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	sender := New(NewPoolDatabase(f.pool))
	client := uuid.NewString()
	first, err := sender.Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: client, Body: "hello", MentionUserIDs: []string{f.peer}}})
	if err != nil || len(first.MentionUserIDs) != 1 || first.MentionUserIDs[0] != f.peer {
		t.Fatalf("send=%#v error=%v", first, err)
	}
	retry, err := sender.Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: client, Body: "changed retry"}})
	if err != nil || retry.ID != first.ID || len(retry.MentionUserIDs) != 1 || retry.MentionUserIDs[0] != f.peer {
		t.Fatalf("retry=%#v error=%v", retry, err)
	}
	page, err := historypostgres.New(historypostgres.NewPoolDatabase(f.pool)).List(ctx, history.Request{Input: history.Input{ActorID: f.peer, DirectMessageID: f.pair, Limit: 10}})
	if err != nil || len(page) != 1 || len(page[0].MentionUserIDs) != 1 || page[0].MentionUserIDs[0] != f.peer {
		t.Fatalf("history=%#v error=%v", page, err)
	}
	_, err = historypostgres.New(historypostgres.NewPoolDatabase(f.pool)).List(ctx, history.Request{Input: history.Input{ActorID: f.outsider, DirectMessageID: f.pair, Limit: 10}})
	if !errors.Is(err, history.ErrDirectMessageUnavailable) {
		t.Fatalf("outsider history error=%v", err)
	}
	assertDMMentionCount(t, f, f.peer, 1)
	assertDMMentionCount(t, f, f.actor, 0)
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.actor, DirectMessageID: f.pair, MessageID: first.ID, Body: "edited", ExpectedRevision: 1}})
	if err != nil {
		t.Fatal(err)
	}
	assertDMMentionCount(t, f, f.peer, 0)
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.actor, DirectMessageID: f.pair, MessageID: first.ID, Body: "edited again", ExpectedRevision: 2, MentionUserIDs: []string{f.peer}}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `INSERT INTO direct_message_read_cursors (account_id,direct_message_id,message_id,message_created_at) SELECT $1,$2,id,created_at FROM direct_message_messages WHERE id=$3`, f.peer, f.pair, first.ID); err != nil {
		t.Fatal(err)
	}
	assertDMMentionCount(t, f, f.peer, 0)
	if _, err := f.pool.Exec(ctx, `UPDATE direct_message_messages SET body='',deleted_at=now() WHERE id=$1`, first.ID); err != nil {
		t.Fatal(err)
	}
	page, err = historypostgres.New(historypostgres.NewPoolDatabase(f.pool)).List(ctx, history.Request{Input: history.Input{ActorID: f.peer, DirectMessageID: f.pair, Limit: 10}})
	if err != nil || len(page[0].MentionUserIDs) != 0 {
		t.Fatalf("deleted history=%#v error=%v", page, err)
	}
}

func TestDMMentionRejectsOutsidePairAtomically(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	client := uuid.NewString()
	_, err := New(NewPoolDatabase(f.pool)).Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: client, Body: "hello", MentionUserIDs: []string{f.outsider}}})
	if !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("error=%v", err)
	}
	assertDMMessageCount(t, f, client, 0)
	first, err := New(NewPoolDatabase(f.pool)).Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "hello"}})
	if err != nil {
		t.Fatal(err)
	}
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.actor, DirectMessageID: f.pair, MessageID: first.ID, Body: "edited", ExpectedRevision: 1, MentionUserIDs: []string{f.outsider}}})
	if !errors.Is(err, edit.ErrConflict) {
		t.Fatalf("outside-pair edit error=%v", err)
	}
	var revision int
	if err := f.pool.QueryRow(ctx, `SELECT revision FROM direct_message_messages WHERE id=$1`, first.ID).Scan(&revision); err != nil || revision != 1 {
		t.Fatalf("revision=%d error=%v", revision, err)
	}
}

func assertDMMentionCount(t *testing.T, f dmFixture, actor string, want int64) {
	t.Helper()
	result, err := listpostgres.New(listpostgres.NewPoolDatabase(f.pool)).List(context.Background(), list.Request{Input: list.Input{ActorID: actor}})
	if err != nil {
		t.Fatal(err)
	}
	for _, dm := range result {
		if dm.ID == f.pair {
			if dm.MentionCount != want {
				t.Fatalf("mention_count=%d want=%d", dm.MentionCount, want)
			}
			return
		}
	}
	t.Fatal("pair missing from participant list")
}
