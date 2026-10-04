package listtopologypostgres

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
	listtopology "voice-platform/backend/internal/channel/list_topology"
)

func TestRepositoryGroupsVisibleChannelsAndCallerLocalUnread(t *testing.T) {
	database := &fakeDatabase{revision: int64(4), rows: &fakeRows{values: [][]any{
		{"category-1", "Игры", 0, pgtype.Text{String: "voice-1", Valid: true}, pgtype.Text{String: "Голос", Valid: true}, pgtype.Text{String: "", Valid: true}, pgtype.Text{String: "VOICE", Valid: true}, pgtype.Int4{Int32: 0, Valid: true}, pgtype.Bool{Bool: true, Valid: true}, pgtype.Int8{}, pgtype.Int8{}, pgtype.Text{}},
		{"category-1", "Игры", 0, pgtype.Text{String: "text-1", Valid: true}, pgtype.Text{String: "Общий", Valid: true}, pgtype.Text{String: "Общение на любые темы", Valid: true}, pgtype.Text{String: "TEXT", Valid: true}, pgtype.Int4{Int32: 1, Valid: true}, pgtype.Bool{Bool: false, Valid: true}, pgtype.Int8{Int64: 3, Valid: true}, pgtype.Int8{Int64: 2, Valid: true}, pgtype.Text{String: "first-1", Valid: true}},
		{"category-2", "Пустая", 1, pgtype.Text{}, pgtype.Text{}, pgtype.Text{}, pgtype.Text{}, pgtype.Int4{}, pgtype.Bool{}, pgtype.Int8{}, pgtype.Int8{}, pgtype.Text{}},
	}}}
	result, err := New(database).List(context.Background(), listtopology.Request{Input: listtopology.Input{ActorID: "actor-1"}})
	if err != nil || result.Revision != 4 || len(result.Categories) != 2 || len(result.Categories[0].Channels) != 2 || !result.Categories[0].Channels[0].AdmissionClosed || result.Categories[0].Channels[1].Description != "Общение на любые темы" || result.Categories[0].Channels[1].UnreadCount != 3 || result.Categories[0].Channels[1].MentionCount != 2 || result.Categories[0].Channels[1].FirstUnreadMessageID != "first-1" || len(result.Categories[1].Channels) != 0 || database.arguments[0] != "actor-1" {
		t.Fatalf("error = %v, result = %#v, statement = %s", err, result, database.statement)
	}
	for _, fragment := range []string{"channel.archived_at IS NULL", "channel.description", "channel.kind = 'TEXT'", "cursor.account_id = $1::uuid", "cursor.channel_id = channel.id", "message.channel_id = channel.id", "message.deleted_at IS NULL", "message.author_id <> $1::uuid", "(message.created_at, message.id) > (cursor.message_created_at, cursor.message_id)"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in query", fragment)
		}
	}
}

type fakeDatabase struct {
	revision  int64
	rows      *fakeRows
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(context.Context, string, ...any) Row {
	return fakeRow{revision: database.revision}
}
func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.arguments = statement, arguments
	return database.rows, nil
}

type fakeRow struct{ revision int64 }

func (row fakeRow) Scan(destination ...any) error {
	*destination[0].(*int64) = row.revision
	return nil
}

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
		case *int:
			*destination = value.(int)
		case *pgtype.Text:
			*destination = value.(pgtype.Text)
		case *pgtype.Int4:
			*destination = value.(pgtype.Int4)
		case *pgtype.Bool:
			*destination = value.(pgtype.Bool)
		case *pgtype.Int8:
			*destination = value.(pgtype.Int8)
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }
