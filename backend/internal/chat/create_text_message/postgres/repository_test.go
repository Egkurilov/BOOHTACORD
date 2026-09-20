package createtextmessagepostgres

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

func TestRepositoryCreatesOrReturnsIdempotentTextMessage(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", "text-1", "user-1", "client-1", "Привет", "message-0", 1, time.Time{}}}}
	attachments := []string{"attachment-1"}
	result, err := New(database).Create(context.Background(), createtextmessage.Request{ID: "message-1", Input: createtextmessage.Input{ChannelID: "text-1", ActorID: "user-1", ClientMessageID: "client-1", Body: "Привет", ReplyToID: "message-0", AttachmentIDs: attachments}})
	if err != nil || result.ID != "message-1" || database.arguments[5] != "message-0" || len(database.arguments) != 7 || !reflect.DeepEqual(database.arguments[6], attachments) {
		t.Fatalf("result = %#v, arguments = %#v, error = %v", result, database.arguments, err)
	}
	for _, fragment := range []string{"existing_message", "attachment.owner_id = $3", "attachment.channel_id = channel.id", "attachment.state = 'UNATTACHED'", "INSERT INTO message_attachments", "SET state = 'ATTACHED'"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsUnavailableChannelOrCrossConversationReply(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Create(context.Background(), createtextmessage.Request{})
	if !errors.Is(err, createtextmessage.ErrChannelUnavailable) {
		t.Fatalf("error = %v", err)
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

type fakeRow struct {
	values []any
	err    error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
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
