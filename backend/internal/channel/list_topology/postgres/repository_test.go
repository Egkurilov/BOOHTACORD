package listtopologypostgres

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
)

func TestRepositoryGroupsVisibleChannelsByCategoryAndKeepsAdmissionState(t *testing.T) {
	database := &fakeDatabase{revision: int64(4), rows: &fakeRows{values: [][]any{{"category-1", "Игры", 0, pgtype.Text{String: "voice-1", Valid: true}, pgtype.Text{String: "Голос", Valid: true}, pgtype.Text{String: "VOICE", Valid: true}, pgtype.Int4{Int32: 0, Valid: true}, pgtype.Bool{Bool: true, Valid: true}}, {"category-1", "Игры", 0, pgtype.Text{String: "text-1", Valid: true}, pgtype.Text{String: "Общий", Valid: true}, pgtype.Text{String: "TEXT", Valid: true}, pgtype.Int4{Int32: 1, Valid: true}, pgtype.Bool{Bool: false, Valid: true}}, {"category-2", "Пустая", 1, pgtype.Text{}, pgtype.Text{}, pgtype.Text{}, pgtype.Int4{}, pgtype.Bool{}}}}}
	result, err := New(database).List(context.Background())
	if err != nil || result.Revision != 4 || len(result.Categories) != 2 || len(result.Categories[0].Channels) != 2 || !result.Categories[0].Channels[0].AdmissionClosed || len(result.Categories[1].Channels) != 0 || !strings.Contains(database.statement, "channel.archived_at IS NULL") {
		t.Fatalf("error = %v, result = %#v, statement = %s", err, result, database.statement)
	}
}

type fakeDatabase struct {
	revision  int64
	rows      *fakeRows
	statement string
}

func (database *fakeDatabase) QueryRow(context.Context, string, ...any) Row {
	return fakeRow{revision: database.revision}
}
func (database *fakeDatabase) Query(_ context.Context, statement string, _ ...any) (Rows, error) {
	database.statement = statement
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
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return nil }
