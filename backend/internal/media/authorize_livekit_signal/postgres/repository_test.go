package authorizelivekitsignalpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
)

func TestAdmitRequiresCurrentLeaseSessionChannelAndAccount(t *testing.T) {
	database := &fakeDatabase{row: fakeRow{}}
	err := New(database).Admit(context.Background(), "lease-1", "channel-1")
	if err != nil || database.leaseID != "lease-1" || database.channelID != "channel-1" {
		t.Fatalf("Admit() error = %v, database = %#v", err, database)
	}
	for _, requirement := range []string{"lease.revoked_at IS NULL", "session.revoked_at IS NULL", "channel.kind = 'VOICE'", "channel.archived_at IS NULL", "channel.admission_closed_at IS NULL", "account.blocked_at IS NULL"} {
		if !strings.Contains(database.statement, requirement) {
			t.Fatalf("statement lacks %q", requirement)
		}
	}
}

func TestAdmitMapsMissingCurrentStateToDenied(t *testing.T) {
	err := New(&fakeDatabase{row: fakeRow{err: pgx.ErrNoRows}}).Admit(context.Background(), "lease-1", "channel-1")
	if !errors.Is(err, authorizelivekitsignal.ErrDenied) {
		t.Fatalf("Admit() error = %v, want ErrDenied", err)
	}
}

type fakeDatabase struct {
	row                fakeRow
	statement          string
	leaseID, channelID string
}

func (database *fakeDatabase) QueryRow(_ context.Context, statement string, values ...any) Row {
	database.statement = statement
	database.leaseID, _ = values[0].(string)
	database.channelID, _ = values[1].(string)
	return database.row
}

type fakeRow struct{ err error }

func (row fakeRow) Scan(...any) error { return row.err }
