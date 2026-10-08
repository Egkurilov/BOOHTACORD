package listmymentionspostgres

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	listmymentions "voice-platform/backend/internal/chat/list_my_mentions"
)

func TestCallerMentionsAreLiveAcrossTextAndOwnDMOnly(t *testing.T) {
	f := newMentionsFixture(t)
	ctx, at := context.Background(), time.Date(2026, 10, 8, 10, 0, 0, 0, time.UTC)
	textLive, dmLive := "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	insertMention(t, f, `INSERT INTO messages (id,channel_id,author_id,client_message_id,body,created_at,mention_user_ids) VALUES ($1,$2,$3,$4,'private body',$5,ARRAY[$6::uuid])`, textLive, f.channel, f.author, uuid.NewString(), at, f.caller)
	insertMention(t, f, `INSERT INTO direct_message_messages (id,direct_message_id,author_id,client_message_id,body,created_at,mention_user_ids) VALUES ($1,$2,$3,$4,'private body',$5,ARRAY[$6::uuid])`, dmLive, f.ownDM, f.author, uuid.NewString(), at, f.caller)
	removed := uuid.NewString()
	insertMention(t, f, `INSERT INTO messages (id,channel_id,author_id,client_message_id,body,created_at,mention_user_ids) VALUES ($1,$2,$3,$4,'edited',$5,ARRAY[$6::uuid])`, removed, f.channel, f.author, uuid.NewString(), at.Add(-time.Minute), f.caller)
	insertMention(t, f, `UPDATE messages SET body='edited',mention_user_ids=ARRAY[]::uuid[],edited_at=now(),revision=revision+1 WHERE id=$1`, removed)
	deleted := uuid.NewString()
	insertMention(t, f, `INSERT INTO messages (id,channel_id,author_id,client_message_id,body,created_at,mention_user_ids) VALUES ($1,$2,$3,$4,'deleted',$5,ARRAY[$6::uuid])`, deleted, f.channel, f.author, uuid.NewString(), at.Add(-2*time.Minute), f.caller)
	insertMention(t, f, `UPDATE messages SET body='',deleted_at=now() WHERE id=$1`, deleted)
	foreign := uuid.NewString()
	insertMention(t, f, `INSERT INTO direct_message_messages (id,direct_message_id,author_id,client_message_id,body,created_at,mention_user_ids) VALUES ($1,$2,$3,$4,'private',$5,ARRAY[$6::uuid])`, foreign, f.otherDM, f.author, uuid.NewString(), at.Add(-3*time.Minute), f.caller)
	insertMention(t, f, `UPDATE users SET display_name='Renamed Author' WHERE id=$1`, f.author)

	service := listmymentions.New(New(NewPoolDatabase(f.pool)))
	first, err := service.List(ctx, listmymentions.Input{ActorID: f.caller, Limit: 1})
	if err != nil || len(first.Mentions) != 1 || first.Mentions[0].ID != textLive || first.Mentions[0].AuthorID != f.author || first.NextCursor == "" {
		t.Fatalf("first=%#v error=%v", first, err)
	}
	second, err := service.List(ctx, listmymentions.Input{ActorID: f.caller, Before: first.NextCursor, Limit: 1})
	if err != nil || len(second.Mentions) != 1 || second.Mentions[0].ID != dmLive || second.Mentions[0].Kind != listmymentions.KindDirectMessage || second.NextCursor != "" {
		t.Fatalf("second=%#v error=%v", second, err)
	}
}

func insertMention(t *testing.T, fixture mentionsFixture, query string, args ...any) {
	t.Helper()
	if _, err := fixture.pool.Exec(context.Background(), query, args...); err != nil {
		t.Fatal("apply mention fixture mutation:", err)
	}
}
