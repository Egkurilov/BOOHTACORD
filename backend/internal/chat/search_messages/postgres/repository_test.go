package searchmessagespostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	searchmessages "voice-platform/backend/internal/chat/search_messages"
)

func TestRepositorySearchesOnlyReadableNonDeletedMessages(t *testing.T) {
	database := &fakeDatabase{available: boolRow{value: true}, rows: &fakeRows{values: [][]any{{
		searchmessages.KindDirectMessage, "44444444-4444-4444-8444-444444444444", "", "33333333-3333-4333-8333-333333333333",
		"11111111-1111-4111-8111-111111111111", "точная фраза", time.Now(), nil, 1,
	}}}}
	result, err := New(database).Search(context.Background(), searchmessages.Request{
		ActorID: "11111111-1111-4111-8111-111111111111", DirectMessageID: "33333333-3333-4333-8333-333333333333", AuthorID: "22222222-2222-4222-8222-222222222222", HasAttachment: boolPointer(false), Query: `"точная фраза"`, Limit: 10,
	})
	if err != nil || len(result) != 1 || result[0].Kind != searchmessages.KindDirectMessage || database.arguments[2] != "33333333-3333-4333-8333-333333333333" || database.arguments[4] != "22222222-2222-4222-8222-222222222222" || database.arguments[5] != false || database.arguments[9] != 11 {
		t.Fatalf("result=%#v args=%#v err=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{
		"UNION ALL", "m.deleted_at IS NULL", "dm_message.deleted_at IS NULL", "$1::uuid IN (dm.participant_one_id, dm.participant_two_id)",
		"channel.kind = 'TEXT' AND channel.archived_at IS NULL", "search_vector @@ websearch_to_tsquery('simple', $4)",
		"message_attachments", "direct_message_attachments", "attachment.state = 'ATTACHED'",
		"ORDER BY created_at DESC, id DESC, kind DESC", "(created_at, id, kind) < ($7::timestamptz, $8::uuid, $9::text)",
	} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q", fragment)
		}
	}
}

func boolPointer(value bool) *bool { return &value }

func TestRepositoryRejectsUnreadableDMFilter(t *testing.T) {
	_, err := New(&fakeDatabase{available: boolRow{value: false}}).Search(context.Background(), searchmessages.Request{DirectMessageID: "33333333-3333-4333-8333-333333333333"})
	if !errors.Is(err, searchmessages.ErrConversationUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

type fakeDatabase struct {
	available boolRow
	rows      *fakeRows
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(context.Context, string, ...any) Row {
	return database.available
}
func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.arguments = statement, arguments
	return database.rows, nil
}

type boolRow struct{ value bool }

func (row boolRow) Scan(destination ...any) error { *destination[0].(*bool) = row.value; return nil }

type fakeRows struct {
	values [][]any
	index  int
}

func (rows *fakeRows) Next() bool { return rows.index < len(rows.values) }
func (rows *fakeRows) Scan(destinations ...any) error {
	values := rows.values[rows.index]
	rows.index++
	for index, value := range values {
		switch destination := destinations[index].(type) {
		case *string:
			*destination = value.(string)
		case *time.Time:
			*destination = value.(time.Time)
		case **time.Time:
			if value != nil {
				copy := value.(time.Time)
				*destination = &copy
			}
		case *int:
			*destination = value.(int)
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }
