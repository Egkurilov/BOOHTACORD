package advancetextchannelreadcursorpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	advancetextchannelreadcursor "voice-platform/backend/internal/chat/advance_text_channel_read_cursor"
)

func TestRepositoryGuardsChannelAndAdvancesMonotonically(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{values: []any{"message-1", time.Unix(1, 0)}}}
	result, err := New(database).Advance(context.Background(), advancetextchannelreadcursor.Request{Input: advancetextchannelreadcursor.Input{ActorID: "actor-1", ChannelID: "channel-1", MessageID: "message-1"}})
	if err != nil || result.MessageID != "message-1" || database.arguments[0] != "actor-1" {
		t.Fatalf("result=%#v arguments=%#v error=%v", result, database.arguments, err)
	}
	for _, fragment := range []string{"channel.kind = 'TEXT'", "channel.archived_at IS NULL", "message.channel_id = channel.id", "message.deleted_at IS NULL", "FOR SHARE OF channel", "ON CONFLICT (account_id, channel_id)", "CASE WHEN (channel_read_cursors.message_created_at, channel_read_cursors.message_id)", "ELSE channel_read_cursors.message_id", "RETURNING message_id::text, message_created_at"} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("missing %q in %s", fragment, database.statement)
		}
	}
	if strings.Contains(database.statement, "WHERE (channel_read_cursors.message_created_at") {
		t.Fatal("backward acknowledgement must return effective cursor")
	}
}

func TestRepositoryMapsWrongChannelAndArchiveToUnavailable(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Advance(context.Background(), advancetextchannelreadcursor.Request{})
	if !errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

func TestRepositoryPreservesOtherDatabaseFailure(t *testing.T) {
	sentinel := errors.New("database unavailable")
	_, err := New(&fakeDatabase{row: fakeRow{err: sentinel}}).Advance(context.Background(), advancetextchannelreadcursor.Request{})
	if !errors.Is(err, sentinel) || errors.Is(err, advancetextchannelreadcursor.ErrChannelUnavailable) {
		t.Fatalf("error=%v", err)
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
	*destinations[0].(*string) = row.values[0].(string)
	*destinations[1].(*time.Time) = row.values[1].(time.Time)
	return nil
}
