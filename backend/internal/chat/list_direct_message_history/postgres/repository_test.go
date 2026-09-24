package listdirectmessagehistorypostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
)

const (
	actorID         = "11111111-1111-4111-8111-111111111111"
	directMessageID = "22222222-2222-4222-8222-222222222222"
)

func TestRepositoryReadsParticipantHistoryAndHidesDeletedContent(t *testing.T) {
	database := &fakeDatabase{available: boolRow{value: true}, rows: &fakeRows{values: [][]any{{"44444444-4444-4444-8444-444444444444", directMessageID, actorID, "55555555-5555-4555-8555-555555555555", "", "66666666-6666-4666-8666-666666666666", time.Unix(1, 0), nil, 1, true, []string{}, "66666666-6666-4666-8666-666666666666", "77777777-7777-4777-8777-777777777777", "", true, []byte(`[]`)}}}}
	result, err := New(database).List(context.Background(), listdirectmessagehistory.Request{Input: listdirectmessagehistory.Input{ActorID: actorID, DirectMessageID: directMessageID, Limit: 2}})
	if err != nil || len(result) != 1 || result[0].Body != "" || result[0].ReplyToID != "66666666-6666-4666-8666-666666666666" || result[0].ReplyPreview == nil || result[0].ReplyPreview.Body != "" || !result[0].ReplyPreview.Deleted || !result[0].Deleted || len(result[0].MentionUserIDs) != 0 || database.arguments[3] != 3 {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	if !strings.Contains(database.availabilityStatement, "$2::uuid IN (dm.participant_one_id, dm.participant_two_id)") {
		t.Fatalf("availability statement=%s", database.availabilityStatement)
	}
	for _, fragment := range []string{"$2::uuid IN (dm.participant_one_id, dm.participant_two_id)", "LEFT JOIN direct_message_messages reply", "reply.direct_message_id = m.direct_message_id", "direct_message_attachments", "m.deleted_at IS NULL", "a.state = 'ATTACHED'", "reply.direct_message_id = m.direct_message_id", "direct_message_id = (SELECT id FROM readable_pair)", "CASE WHEN m.deleted_at IS NULL THEN m.body ELSE '' END", "CASE WHEN reply.deleted_at IS NULL THEN COALESCE(reply.body, '') ELSE '' END", "COALESCE(m.reply_to_id::text, '')", "ORDER BY m.created_at DESC, m.id DESC"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.availabilityStatement, "blocked_at") || strings.Contains(database.statement, "blocked_at") {
		t.Fatalf("history must remain available to the other participant after a block")
	}
}

func TestRepositoryRejectsForeignParticipantWithoutRoleBypass(t *testing.T) {
	_, err := New(&fakeDatabase{available: boolRow{value: false}}).List(context.Background(), listdirectmessagehistory.Request{Input: listdirectmessagehistory.Input{ActorID: actorID, DirectMessageID: directMessageID, Limit: 1}})
	if !errors.Is(err, listdirectmessagehistory.ErrDirectMessageUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

type fakeDatabase struct {
	available             boolRow
	rows                  *fakeRows
	availabilityStatement string
	statement             string
	arguments             []any
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, _ ...any) Row {
	database.availabilityStatement = statement
	return database.available
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
