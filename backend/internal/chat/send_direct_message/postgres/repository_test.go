package senddirectmessagepostgres

import (
	"context"
	"strings"
	"testing"
	"time"

	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
)

func TestRepositoryWritesOnlyForActiveParticipantPair(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"44444444-4444-4444-8444-444444444444", "22222222-2222-4222-8222-222222222222", "11111111-1111-4111-8111-111111111111", "33333333-3333-4333-8333-333333333333", "Привет", "55555555-5555-4555-8555-555555555555", 1, time.Unix(1, 0)}}}
	result, err := New(database).Send(context.Background(), senddirectmessage.Request{ID: "44444444-4444-4444-8444-444444444444", Input: senddirectmessage.Input{ActorID: "11111111-1111-4111-8111-111111111111", DirectMessageID: "22222222-2222-4222-8222-222222222222", ClientMessageID: "33333333-3333-4333-8333-333333333333", ReplyToID: "55555555-5555-4555-8555-555555555555", Body: "Привет", AttachmentIDs: []string{"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}}})
	if err != nil || result.AuthorID != "11111111-1111-4111-8111-111111111111" || result.ReplyToID != "55555555-5555-4555-8555-555555555555" || database.arguments[1] != "22222222-2222-4222-8222-222222222222" || database.arguments[5] != "55555555-5555-4555-8555-555555555555" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	if len(database.arguments) != 8 {
		t.Fatalf("arguments=%#v", database.arguments)
	}
	for _, fragment := range []string{"$3::uuid IN (dm.participant_one_id, dm.participant_two_id)", "blocked_at IS NULL", "$6::uuid IS NULL OR EXISTS", "reply.direct_message_id = active_pair.id", "COALESCE(reply_to_id::text, '')", "ON CONFLICT (author_id, direct_message_id, client_message_id)", "direct_message_attachments", "FOR UPDATE OF attachment", "attachment.owner_id = $3", "attachment.direct_message_id = active_pair.id"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
}

type fakeDatabase struct {
	row       fakeRow
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, arguments ...any) Row {
	database.statement, database.arguments = statement, arguments
	return database.row
}

type fakeRow struct{ values []any }

func (row fakeRow) Scan(destinations ...any) error {
	for index, value := range row.values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *int:
			*destination = value.(int)
		case *time.Time:
			*destination = value.(time.Time)
		}
	}
	return nil
}
