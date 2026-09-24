package authorizedirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	match "voice-platform/backend/internal/storage/authorize_direct_message_attachment"
)

func TestAuthorizationRequiresExactPairAndBothActive(t *testing.T) {
	row := fakeRow{}
	db := &fakeDatabase{row: row}
	err := New(db).Authorize(context.Background(), match.Input{ActorID: "actor", DirectMessageID: "pair"})
	if err != nil || db.args[0] != "actor" || db.args[1] != "pair" {
		t.Fatalf("error=%v args=%#v", err, db.args)
	}
	for _, fragment := range []string{"participant_one_id", "participant_two_id", "blocked_at IS NULL", "$1::uuid IN"} {
		if !strings.Contains(db.query, fragment) {
			t.Fatalf("query lacks %q", fragment)
		}
	}
	db.row.err = pgx.ErrNoRows
	if err := New(db).Authorize(context.Background(), match.Input{}); !errors.Is(err, match.ErrTargetUnavailable) {
		t.Fatalf("error=%v", err)
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

type fakeRow struct{ err error }

func (row fakeRow) Scan(destinations ...any) error {
	if row.err != nil {
		return row.err
	}
	*destinations[0].(*int) = 1
	return nil
}
