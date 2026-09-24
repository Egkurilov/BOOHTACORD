package listtextmessagespostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
)

const attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"

func TestRepositoryReadsOrderedSafeAttachmentsAndHidesDeletedMessageLinks(t *testing.T) {
	attachments := []byte(`[{"id":"c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610","original_name":"notes.svg","byte_size":10}]`)
	database := &fakeDatabase{channel: boolRow{value: true}, rows: &fakeRows{values: [][]any{
		{"message-2", "channel-1", "user-1", "client-2", "body", "", time.Time{}, nil, 1, false, []string{"user-2"}, attachments},
		{"message-1", "channel-1", "user-1", "client-1", "", "", time.Time{}, nil, 1, true, []string{}, []byte(`[]`)},
	}}}
	result, err := New(database).List(context.Background(), listtextmessages.Request{Input: listtextmessages.Input{ChannelID: "channel-1", Limit: 2}})
	if err != nil || len(result) != 2 || result[0].Attachments[0].ID != attachmentID || result[0].Attachments[0].OriginalName != "notes.svg" || result[0].Attachments[0].SizeBytes != 10 || len(result[0].MentionUserIDs) != 1 || result[0].MentionUserIDs[0] != "user-2" || result[1].Body != "" || !result[1].Deleted || len(result[1].Attachments) != 0 || len(result[1].MentionUserIDs) != 0 || database.arguments[2] != 3 {
		t.Fatalf("result = %#v, arguments = %#v, error = %v", result, database.arguments, err)
	}
	for _, fragment := range []string{
		"CASE WHEN messages.deleted_at IS NULL THEN messages.body ELSE '' END", "attachments.state = 'ATTACHED'", "message_attachments.position", "messages.deleted_at IS NULL", "'[]'::jsonb", "ORDER BY messages.created_at DESC, messages.id DESC",
	} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q", fragment)
		}
	}
	if !strings.Contains(database.channelStatement, "kind = 'TEXT'") {
		t.Fatalf("channel statement = %s", database.channelStatement)
	}
}

func TestRepositoryMapsArchivedOrVoiceChannelToUnavailable(t *testing.T) {
	_, err := New(&fakeDatabase{channel: boolRow{value: false}}).List(context.Background(), listtextmessages.Request{})
	if !errors.Is(err, listtextmessages.ErrChannelUnavailable) {
		t.Fatalf("error = %v", err)
	}
}

type fakeDatabase struct {
	channel          boolRow
	rows             *fakeRows
	channelStatement string
	statement        string
	arguments        []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, _ ...any) Row {
	database.channelStatement = statement
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
		case *bool:
			*destination = value.(bool)
		case *[]byte:
			*destination = value.([]byte)
		case *[]string:
			*destination = value.([]string)
		}
	}
	return nil
}
func (rows *fakeRows) Close()     {}
func (rows *fakeRows) Err() error { return rows.err }

var _ = pgx.ErrNoRows
