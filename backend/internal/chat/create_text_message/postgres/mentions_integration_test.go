package createtextmessagepostgres

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	topology "voice-platform/backend/internal/channel/list_topology"
	topologypostgres "voice-platform/backend/internal/channel/list_topology/postgres"
	create "voice-platform/backend/internal/chat/create_text_message"
	edit "voice-platform/backend/internal/chat/edit_text_message"
	editpostgres "voice-platform/backend/internal/chat/edit_text_message/postgres"
	history "voice-platform/backend/internal/chat/list_text_messages"
	historypostgres "voice-platform/backend/internal/chat/list_text_messages/postgres"
)

func TestTextMentionsRetainIDsAndFollowEditDeleteAndCursor(t *testing.T) {
	f := newTextMessageFixture(t)
	ctx := context.Background()
	recipient := uuid.NewString()
	if _, err := f.pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,'mentiontarget','Old Name','test','MEMBER')`, recipient); err != nil {
		t.Fatal(err)
	}
	sender := New(NewPoolDatabase(f.pool))
	first, err := sender.Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{ActorID: f.authorID, ChannelID: f.channelID, ClientMessageID: uuid.NewString(), Body: "hello", MentionUserIDs: []string{recipient}}})
	if err != nil || len(first.MentionUserIDs) != 1 || first.MentionUserIDs[0] != recipient {
		t.Fatalf("send=%#v error=%v", first, err)
	}
	retry, err := sender.Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{ActorID: f.authorID, ChannelID: f.channelID, ClientMessageID: first.ClientMessageID, Body: "different retry"}})
	if err != nil || retry.ID != first.ID || len(retry.MentionUserIDs) != 1 || retry.MentionUserIDs[0] != recipient {
		t.Fatalf("retry=%#v error=%v", retry, err)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE users SET display_name='New Name' WHERE id=$1`, recipient); err != nil {
		t.Fatal(err)
	}
	page, err := historypostgres.New(historypostgres.NewPoolDatabase(f.pool)).List(ctx, history.Request{Input: history.Input{ChannelID: f.channelID, Limit: 10}})
	if err != nil || len(page) != 1 || len(page[0].MentionUserIDs) != 1 || page[0].MentionUserIDs[0] != recipient {
		t.Fatalf("history=%#v error=%v", page, err)
	}
	assertTextMentionCount(t, f, recipient, 1)
	assertTextMentionCount(t, f, f.authorID, 0)
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.authorID, ChannelID: f.channelID, MessageID: first.ID, Body: "edited", ExpectedRevision: 1}})
	if err != nil {
		t.Fatal(err)
	}
	assertTextMentionCount(t, f, recipient, 0)
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.authorID, ChannelID: f.channelID, MessageID: first.ID, Body: "edited again", ExpectedRevision: 2, MentionUserIDs: []string{recipient}}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `INSERT INTO channel_read_cursors (account_id,channel_id,message_id,message_created_at) SELECT $1,$2,id,created_at FROM messages WHERE id=$3`, recipient, f.channelID, first.ID); err != nil {
		t.Fatal(err)
	}
	assertTextMentionCount(t, f, recipient, 0)
	if _, err := f.pool.Exec(ctx, `UPDATE messages SET body='',deleted_at=now() WHERE id=$1`, first.ID); err != nil {
		t.Fatal(err)
	}
	page, err = historypostgres.New(historypostgres.NewPoolDatabase(f.pool)).List(ctx, history.Request{Input: history.Input{ChannelID: f.channelID, Limit: 10}})
	if err != nil || len(page[0].MentionUserIDs) != 0 {
		t.Fatalf("deleted history=%#v error=%v", page, err)
	}
}

func TestTextMentionRejectsUnknownRecipientAtomically(t *testing.T) {
	f := newTextMessageFixture(t)
	ctx := context.Background()
	client := uuid.NewString()
	_, err := New(NewPoolDatabase(f.pool)).Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{ActorID: f.authorID, ChannelID: f.channelID, ClientMessageID: client, Body: "hello", MentionUserIDs: []string{uuid.NewString()}}})
	if !errors.Is(err, create.ErrChannelUnavailable) {
		t.Fatalf("error=%v", err)
	}
	assertMessageCount(t, f, client, 0)
	blocked := uuid.NewString()
	if _, err := f.pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role,blocked_at) VALUES ($1,'blockedmention','Blocked','test','MEMBER',now())`, blocked); err != nil {
		t.Fatal(err)
	}
	_, err = New(NewPoolDatabase(f.pool)).Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{ActorID: f.authorID, ChannelID: f.channelID, ClientMessageID: uuid.NewString(), Body: "hello", MentionUserIDs: []string{blocked}}})
	if !errors.Is(err, create.ErrChannelUnavailable) {
		t.Fatalf("blocked target error=%v", err)
	}
	first, err := New(NewPoolDatabase(f.pool)).Create(ctx, create.Request{ID: uuid.NewString(), Input: create.Input{ActorID: f.authorID, ChannelID: f.channelID, ClientMessageID: uuid.NewString(), Body: "hello"}})
	if err != nil {
		t.Fatal(err)
	}
	_, err = editpostgres.New(editpostgres.NewPoolDatabase(f.pool)).Edit(ctx, edit.Request{Input: edit.Input{ActorID: f.authorID, ChannelID: f.channelID, MessageID: first.ID, Body: "edited", ExpectedRevision: 1, MentionUserIDs: []string{blocked}}})
	if !errors.Is(err, edit.ErrConflict) {
		t.Fatalf("blocked edit target error=%v", err)
	}
	var revision int
	if err := f.pool.QueryRow(ctx, `SELECT revision FROM messages WHERE id=$1`, first.ID).Scan(&revision); err != nil || revision != 1 {
		t.Fatalf("revision=%d error=%v", revision, err)
	}
}

func assertTextMentionCount(t *testing.T, f textMessageFixture, actor string, want int64) {
	t.Helper()
	result, err := topologypostgres.New(topologypostgres.NewPoolDatabase(f.pool)).List(context.Background(), topology.Request{Input: topology.Input{ActorID: actor}})
	if err != nil || len(result.Categories) != 1 || len(result.Categories[0].Channels) != 1 || result.Categories[0].Channels[0].MentionCount != want {
		t.Fatalf("topology=%#v want=%d error=%v", result, want, err)
	}
}
