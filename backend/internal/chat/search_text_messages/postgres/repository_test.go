package searchtextmessagespostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
)

func TestRepositorySearchesOnlyCurrentTextChannelMessages(t *testing.T) {
	database := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{values: [][]any{{"message-2", "channel-1", "user-1", "Привет, Лера", time.Time{}, nil, 1}}}}
	result, err := New(database).Search(context.Background(), searchtextmessages.Request{Input: searchtextmessages.Input{ChannelID: "channel-1", Query: `"Привет Лера"`, Limit: 2}})
	if err != nil || len(result) != 1 || result[0].Body != "Привет, Лера" || database.arguments[3] != 3 {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"kind = 'TEXT'", "archived_at IS NULL", "m.deleted_at IS NULL", "m.search_vector @@ websearch_to_tsquery('simple', $3)", "ORDER BY m.created_at DESC, m.id DESC"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q", fragment)
		}
	}
}

func TestRepositoryMapsUnavailableTextChannel(t *testing.T) {
	_, err := New(&fakeDatabase{channel: boolRow{value: false}}).Search(context.Background(), searchtextmessages.Request{})
	if !errors.Is(err, searchtextmessages.ErrChannelUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

type fakeDatabase struct {
	channel   boolRow
	rows      *fakeRows
	statement string
	arguments []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, _ string, _ ...any) Row {
	return database.channel
}
func (database *fakeDatabase) Query(_ context.Context, statement string, arguments ...any) (Rows, error) {
	database.statement, database.arguments = statement, arguments
	return database.rows, nil
}

type boolRow struct {
	value bool
	err   error
}

func (row boolRow) Scan(destination ...any) error {
	if row.err != nil {
		return row.err
	}
	*(destination[0].(*bool)) = row.value
	return nil
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
func (rows *fakeRows) Err() error { return rows.err }

var _ = pgx.ErrNoRows
