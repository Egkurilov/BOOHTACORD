package senddirectmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	list "voice-platform/backend/internal/chat/list_direct_message_history"
	listpostgres "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	send "voice-platform/backend/internal/chat/send_direct_message"
)

func TestDMAttachIsAtomicAndIdempotentWithPostgres(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	repository := New(NewPoolDatabase(f.pool))
	request := send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "attached", AttachmentIDs: []string{f.attachment}}}
	first, err := repository.Send(ctx, request)
	if err != nil {
		t.Fatal(err)
	}
	request.ID, request.Body = uuid.NewString(), "changed on retry"
	retry, err := repository.Send(ctx, request)
	if err != nil || retry.ID != first.ID || retry.Body != first.Body {
		t.Fatalf("first=%#v retry=%#v error=%v", first, retry, err)
	}
	var links int
	var state string
	if err := f.pool.QueryRow(ctx, `SELECT count(*) FROM direct_message_attachments WHERE message_id=$1`, first.ID).Scan(&links); err != nil {
		t.Fatal(err)
	}
	if err := f.pool.QueryRow(ctx, `SELECT state FROM attachments WHERE id=$1`, f.attachment).Scan(&state); err != nil {
		t.Fatal(err)
	}
	if links != 1 || state != "ATTACHED" {
		t.Fatalf("links=%d state=%s", links, state)
	}
	history := list.New(listpostgres.New(listpostgres.NewPoolDatabase(f.pool)))
	page, err := history.List(ctx, list.Input{ActorID: f.peer, DirectMessageID: f.pair, Limit: 10})
	if err != nil || len(page.Messages) != 1 || len(page.Messages[0].Attachments) != 1 || page.Messages[0].Attachments[0].ID != f.attachment {
		t.Fatalf("history=%#v error=%v", page, err)
	}
	second := send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "reuse", AttachmentIDs: []string{f.attachment}}}
	if _, err := repository.Send(ctx, second); !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("reused attachment error=%v", err)
	}
	assertDMMessageCount(t, f, second.ClientMessageID, 0)
	if _, err := f.pool.Exec(ctx, `UPDATE direct_message_messages SET body='', deleted_at=now() WHERE id=$1`, first.ID); err != nil {
		t.Fatal(err)
	}
	page, err = history.List(ctx, list.Input{ActorID: f.peer, DirectMessageID: f.pair, Limit: 10})
	if err != nil || len(page.Messages) != 1 || len(page.Messages[0].Attachments) != 0 {
		t.Fatalf("deleted history=%#v error=%v", page, err)
	}
}

func TestDMAttachRejectsForeignPairAndPartialSet(t *testing.T) {
	f := newDMFixture(t)
	ctx := context.Background()
	other := uuid.NewString()
	_, err := f.pool.Exec(ctx, `INSERT INTO attachments (id,owner_id,direct_message_id,original_name,storage_key,byte_size,state) VALUES ($1,$2,$3,'foreign',$4,1,'UNATTACHED')`, other, f.peer, f.otherPair, uuid.NewString())
	if err != nil {
		t.Fatal(err)
	}
	clientID := uuid.NewString()
	_, err = New(NewPoolDatabase(f.pool)).Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: clientID, Body: "partial", AttachmentIDs: []string{f.attachment, other}}})
	if !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("partial attach error=%v", err)
	}
	assertDMMessageCount(t, f, clientID, 0)
	var state string
	if err := f.pool.QueryRow(ctx, `SELECT state FROM attachments WHERE id=$1`, f.attachment).Scan(&state); err != nil || state != "UNATTACHED" {
		t.Fatalf("state=%q error=%v", state, err)
	}
	_, err = New(NewPoolDatabase(f.pool)).Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.outsider, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "admin"}})
	if !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("outsider administrator error=%v", err)
	}
	_, err = f.pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, f.peer)
	if err != nil {
		t.Fatal(err)
	}
	_, err = New(NewPoolDatabase(f.pool)).Send(ctx, send.Request{ID: uuid.NewString(), Input: send.Input{ActorID: f.actor, DirectMessageID: f.pair, ClientMessageID: uuid.NewString(), Body: "blocked", AttachmentIDs: []string{f.attachment}}})
	if !errors.Is(err, send.ErrDirectMessageUnavailable) {
		t.Fatalf("blocked pair error=%v", err)
	}
}

func assertDMMessageCount(t *testing.T, f dmFixture, clientID string, want int) {
	t.Helper()
	var count int
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM direct_message_messages WHERE client_message_id=$1`, clientID).Scan(&count); err != nil || count != want {
		t.Fatalf("count=%d want=%d error=%v", count, want, err)
	}
}
