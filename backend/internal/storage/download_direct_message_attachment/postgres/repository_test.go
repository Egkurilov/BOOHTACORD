package downloaddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
)

func TestFindRequiresLiveSamePairLinkAndParticipant(t *testing.T) {
	db := &fakeDatabase{row: fakeRow{metadata: download.Metadata{OriginalName: "x.svg", StorageKey: "d1b4cc4a-2f12-4c7e-8f18-9d6dba5c6610", SizeBytes: 10}}}
	input := download.Input{ActorID: "actor", DirectMessageID: "pair", AttachmentID: "attachment"}
	metadata, err := New(db).Find(context.Background(), input)
	if err != nil || metadata.OriginalName != "x.svg" || len(db.args) != 3 || db.args[0] != input.ActorID || db.args[1] != input.DirectMessageID || db.args[2] != input.AttachmentID {
		t.Fatalf("metadata=%#v args=%#v err=%v", metadata, db.args, err)
	}
	for _, fragment := range []string{
		"actor.blocked_at IS NULL", "$1::uuid IN (dm.participant_one_id, dm.participant_two_id)",
		"dm.id = $2", "link.attachment_id = $3", "message.direct_message_id = dm.id",
		"message.deleted_at IS NULL", "attachment.direct_message_id = dm.id", "attachment.state = 'ATTACHED'",
	} {
		if !strings.Contains(db.query, fragment) {
			t.Fatalf("query lacks %q: %s", fragment, db.query)
		}
	}
	if strings.Contains(db.query, "peer.blocked_at") || strings.Contains(db.query, "role") {
		t.Fatalf("query unexpectedly restricts peer history or grants role exception: %s", db.query)
	}
}

func TestFindMapsEveryMissingPredicateToUniformUnavailable(t *testing.T) {
	_, err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Find(context.Background(), download.Input{})
	if !errors.Is(err, download.ErrAttachmentUnavailable) {
		t.Fatalf("err=%v", err)
	}
}

type fakeDatabase struct {
	row   fakeRow
	query string
	args  []any
}

func (db *fakeDatabase) QueryRow(_ context.Context, query string, args ...any) Row {
	db.query, db.args = query, args
	return db.row
}

type fakeRow struct {
	metadata download.Metadata
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
