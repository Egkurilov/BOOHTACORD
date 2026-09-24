package createtextmessagepostgres

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

func TestRepositoryRecoversConcurrentIdempotencyConflict(t *testing.T) {
	conflict := &pgconn.PgError{Code: "23505", ConstraintName: "messages_author_channel_client_message_unique"}
	database := &fakeDatabase{rows: []fakeRow{
		{err: conflict},
		{values: []any{"committed-id", "channel-id", "author-id", "client-id", "first body", "", 1, time.Time{}}},
	}}
	request := createtextmessage.Request{ID: "proposed-id", Input: createtextmessage.Input{
		ChannelID: "channel-id", ActorID: "author-id", ClientMessageID: "client-id", Body: "second body",
	}}
	result, err := New(database).Create(context.Background(), request)
	if err != nil || result.ID != "committed-id" || result.Body != "first body" {
		t.Fatalf("result = %#v, error = %v", result, err)
	}
	if database.calls != 2 || !strings.Contains(database.statements[1], "FROM messages") ||
		!reflect.DeepEqual(database.allArguments[1], []any{"author-id", "channel-id", "client-id"}) {
		t.Fatalf("calls = %d, statements = %#v, arguments = %#v", database.calls, database.statements, database.allArguments)
	}
}

func TestRepositoryDoesNotRecoverOtherUniqueConflict(t *testing.T) {
	conflict := &pgconn.PgError{Code: "23505", ConstraintName: "messages_pkey"}
	database := &fakeDatabase{row: fakeRow{err: conflict}}
	_, err := New(database).Create(context.Background(), createtextmessage.Request{})
	if !errors.Is(err, conflict) || database.calls != 1 {
		t.Fatalf("error = %v, calls = %d", err, database.calls)
	}
}

func TestRepositoryPreservesConflictWhenWinnerCannotBeRead(t *testing.T) {
	conflict := &pgconn.PgError{Code: "23505", ConstraintName: "messages_author_channel_client_message_unique"}
	database := &fakeDatabase{rows: []fakeRow{{err: conflict}, {err: pgx.ErrNoRows}}}
	_, err := New(database).Create(context.Background(), createtextmessage.Request{})
	if !errors.Is(err, conflict) || database.calls != 2 {
		t.Fatalf("error = %v, calls = %d", err, database.calls)
	}
}

func TestRepositoryRecoversConcurrentAttachmentClaim(t *testing.T) {
	database := &fakeDatabase{rows: []fakeRow{
		{err: pgx.ErrNoRows},
		{values: []any{"committed-id", "channel-id", "author-id", "client-id", "first body", "", 1, time.Time{}}},
	}}
	request := createtextmessage.Request{Input: createtextmessage.Input{
		ChannelID: "channel-id", ActorID: "author-id", ClientMessageID: "client-id", AttachmentIDs: []string{"attachment-id"},
	}}
	result, err := New(database).Create(context.Background(), request)
	if err != nil || result.ID != "committed-id" || database.calls != 2 {
		t.Fatalf("result = %#v, error = %v, calls = %d", result, err, database.calls)
	}
}
