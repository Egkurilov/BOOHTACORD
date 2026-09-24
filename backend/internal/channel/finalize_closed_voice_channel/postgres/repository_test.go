package finalizeclosedvoicechannelpostgres

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
)

func TestCandidatesRequireClosedVoiceAndCompletedRemovals(t *testing.T) {
	database := &fakeDatabase{rows: &fakeRows{values: []string{"channel-1"}}}
	ids, err := New(database).Candidates(context.Background(), 7, "")
	if err != nil || len(ids) != 1 || ids[0] != "channel-1" || database.queryArgs[0] != 7 {
		t.Fatalf("ids=%v err=%v args=%v", ids, err, database.queryArgs)
	}
	if len(database.queryArgs) != 2 || database.queryArgs[1] != nil {
		t.Fatalf("initial cursor args=%v", database.queryArgs)
	}
	for _, required := range []string{"kind = 'VOICE'", "admission_closed_at IS NOT NULL", "archived_at IS NULL", "lease.revoked_at IS NULL", "revocation.completed_at IS NULL", "channel.id > $2::uuid", "LIMIT $1"} {
		if !strings.Contains(database.query, required) {
			t.Fatalf("candidate guard %q missing", required)
		}
	}
	_, err = New(database).Candidates(context.Background(), 7, "11111111-1111-4111-8111-111111111111")
	if err != nil || database.queryArgs[1] != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("cursor args=%v err=%v", database.queryArgs, err)
	}
}

func TestFinalizeRechecksGuardsUnderTopologyLockAndCommitsRevision(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{revision: 9}}
	database := &fakeDatabase{transaction: transaction}
	revision, err := New(database).Finalize(context.Background(), "channel-1")
	if err != nil || revision != 9 || !transaction.locked || !transaction.committed || transaction.rolledBack {
		t.Fatalf("revision=%d err=%v transaction=%#v", revision, err, transaction)
	}
	if len(transaction.args) != 1 || transaction.args[0] != "channel-1" {
		t.Fatalf("arguments=%v", transaction.args)
	}
	for _, required := range []string{"kind = 'VOICE'", "admission_closed_at IS NOT NULL", "archived_at IS NULL", "lease.revoked_at IS NULL", "revocation.completed_at IS NULL", "archived_at = now()", "revision = revision + 1", "VOICE_CHANNEL_ARCHIVED", "jsonb_build_object('channel_id'"} {
		if !strings.Contains(transaction.statement, required) {
			t.Fatalf("finalization guard %q missing", required)
		}
	}
}

func TestFinalizeIsIdempotentWhenAlreadyArchivedOrPending(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	revision, err := New(&fakeDatabase{transaction: transaction}).Finalize(context.Background(), "channel-1")
	if err != nil || revision != 0 || !transaction.rolledBack || transaction.committed {
		t.Fatalf("revision=%d err=%v transaction=%#v", revision, err, transaction)
	}
}

func TestFinalizeDoesNotClaimCommitOnFailure(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{revision: 9}, commitErr: errors.New("database unavailable")}
	revision, err := New(&fakeDatabase{transaction: transaction}).Finalize(context.Background(), "channel-1")
	if err == nil || revision != 0 || !transaction.rolledBack {
		t.Fatalf("revision=%d err=%v transaction=%#v", revision, err, transaction)
	}
}
