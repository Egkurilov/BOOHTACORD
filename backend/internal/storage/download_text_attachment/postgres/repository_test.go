package downloadtextattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

const (
	actorID      = "a1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	channelID    = "b1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	attachmentID = "c1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
	storageKey   = "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610"
)

func TestRepositoryFindsOnlyAttachmentLinkedToCurrentNonDeletedTextMessage(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{metadata: downloadtextattachment.Metadata{OriginalName: "game-log.svg", StorageKey: storageKey, SizeBytes: 10}}}
	metadata, err := New(database).Find(context.Background(), downloadtextattachment.Input{ActorID: actorID, ChannelID: channelID, AttachmentID: attachmentID})
	if err != nil || metadata.OriginalName != "game-log.svg" || len(database.arguments) != 4 || database.arguments[3] != false || database.arguments[0] != actorID || database.arguments[1] != channelID || database.arguments[2] != attachmentID {
		t.Fatalf("metadata = %#v, arguments = %#v, error = %v", metadata, database.arguments, err)
	}
	for _, fragment := range []string{
		"users.blocked_at IS NULL", "channels.kind = 'TEXT'", "channels.archived_at IS NULL",
		"attachments.state = 'ATTACHED'", "messages.deleted_at IS NULL",
		"message_attachments.attachment_id = attachments.id", "attachments.channel_id = channels.id",
		"users.id = $1", "channels.id = $2", "attachments.id = $3",
	} {
		if !strings.Contains(database.statement, fragment) {
			t.Fatalf("statement does not include %q: %s", fragment, database.statement)
		}
	}
}

func TestRepositoryMapsAnyUnavailablePredicateToOneError(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Find(context.Background(), downloadtextattachment.Input{})
	if !errors.Is(err, downloadtextattachment.ErrAttachmentUnavailable) {
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
	metadata downloadtextattachment.Metadata
	err      error
}

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*string) = row.metadata.OriginalName
	*destinations[1].(*string) = row.metadata.StorageKey
	*destinations[2].(*int64) = row.metadata.SizeBytes
	return nil
}
