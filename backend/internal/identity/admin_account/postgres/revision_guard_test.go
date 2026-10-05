package adminpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"strings"
	"testing"
	adminaccount "voice-platform/backend/internal/identity/admin_account"
)

func TestExpectedUpdateConflictsBeforeAuditOrCommit(t *testing.T) {
	transaction := &fakeTransaction{row: fakeRow{err: pgx.ErrNoRows}}
	_, err := New(&fakeDatabase{transaction: transaction}).Update(context.Background(), adminaccount.Input{ExpectedUpdatedAt: "2026-10-05T12:00:00.123456Z"})
	if !errors.Is(err, adminaccount.ErrRevisionConflict) || transaction.committed || !transaction.rolledBack {
		t.Fatalf("conflict=%v commit=%v rollback=%v", err, transaction.committed, transaction.rolledBack)
	}
	if !strings.Contains(transaction.statement, "updated_at = $5::timestamptz") || transaction.arguments[4] != "2026-10-05T12:00:00.123456Z" {
		t.Fatal("missing atomic revision guard")
	}
}
