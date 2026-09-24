package listdirectmessagespostgres

import (
	"context"
	"strings"
	"testing"
	"time"

	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
)

func TestRepositoryReturnsOnlyPairedAccountAndKeepsBlockedPairVisible(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: [][]any{{"22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333", "Собеседник", time.Unix(1, 0), int64(3), int64(2)}}}}
	result, err := New(database).List(context.Background(), listdirectmessages.Request{Input: listdirectmessages.Input{ActorID: "11111111-1111-4111-8111-111111111111"}})
	if err != nil || len(result) != 1 || result[0].OtherParticipantDisplayName != "Собеседник" || result[0].UnreadCount != 3 || result[0].MentionCount != 2 || database.arguments[0] != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"participant_one_id = $1::uuid", "participant_two_id = $1::uuid", "JOIN users account ON account.id = pair.other_participant_id", "LEFT JOIN direct_message_read_cursors cursor", "cursor.account_id = $1::uuid", "message.author_id <> $1::uuid", "(message.created_at, message.id) > (cursor.message_created_at, cursor.message_id)", "ORDER BY pair.created_at DESC, pair.id DESC"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.statement, "blocked_at") || strings.Contains(database.statement, "ADMINISTRATOR") || strings.Contains(database.statement, "message.body") || strings.Contains(database.statement, "message.edited_at") {
		t.Fatalf("navigation count must preserve blocked history without role or message-content leakage")
	}
}

type fakeDatabase struct {
	rows      *fakeRows
	statement string
	arguments []any
}

func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.arguments = statement, arguments
	return database.rows, nil
}

type fakeRows struct {
	values [][]any
	index  int
	err    error
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
		case *int64:
			*destination = value.(int64)
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return rows.err }
