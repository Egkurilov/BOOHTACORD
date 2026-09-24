package finalizestageddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	finalize "voice-platform/backend/internal/storage/finalize_staged_direct_message_attachment"
)

func TestCreateRechecksActivePairAndPersistsUnattachedTarget(t *testing.T) {
	db := &fakeDatabase{row: fakeRow{}}
	request := finalize.Request{ID: "id", ActorID: "actor", DirectMessageID: "pair", OriginalName: "file", StorageKey: "key", SizeBytes: 1}
	if _, err := New(db).Create(context.Background(), request); err != nil {
		t.Fatal(err)
	}
	for _, fragment := range []string{"participant_one_id", "participant_two_id", "blocked_at IS NULL", "FOR SHARE OF one, two", "direct_message_id", "'UNATTACHED'"} {
		if !strings.Contains(db.query, fragment) {
			t.Fatalf("query lacks %q", fragment)
		}
	}
	db.row.err = pgx.ErrNoRows
	if _, err := New(db).Create(context.Background(), request); !errors.Is(err, finalize.ErrTargetUnavailable) {
		t.Fatalf("error=%v", err)
	}
}

type fakeDatabase struct {
	row   fakeRow
	query string
}

func (db *fakeDatabase) QueryRow(_ context.Context, query string, _ ...any) Row {
	db.query = query
	return db.row
}

type fakeRow struct{ err error }

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	for _, destination := range destinations {
		switch value := destination.(type) {
		case *string:
			*value = "id"
		case *int64:
			*value = 1
		}
	}
	return nil
}
