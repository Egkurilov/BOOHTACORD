package migrate

import (
	"context"
	"testing"
	"time"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"

	"github.com/google/uuid"
)

func TestDeletingStateMigrationInDisposableSchema(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackOrLocalhost)
	_, err := pool.Exec(ctx, `CREATE TABLE attachments (
    id uuid PRIMARY KEY, storage_key uuid NOT NULL, state text NOT NULL
        CONSTRAINT attachments_state_check CHECK (state IN ('UNATTACHED','ATTACHED','HIDDEN')),
    created_at timestamptz NOT NULL, attached_at timestamptz, hidden_at timestamptz,
    CONSTRAINT attachments_state_timestamps CHECK (
        (state='UNATTACHED' AND attached_at IS NULL AND hidden_at IS NULL) OR
        (state='ATTACHED' AND attached_at IS NOT NULL AND hidden_at IS NULL) OR
        (state='HIDDEN' AND attached_at IS NOT NULL AND hidden_at IS NOT NULL)))`)
	if err != nil {
		t.Fatal(err)
	}
	id := uuid.New()
	if _, err := pool.Exec(ctx, `INSERT INTO attachments VALUES ($1,$2,'UNATTACHED',now(),NULL,NULL)`, id, uuid.New()); err != nil {
		t.Fatal(err)
	}
	migration, err := files.ReadFile("migrations/0031_add_attachment_deleting_state.sql")
	if err != nil {
		t.Fatal(err)
	}
	for run := 0; run < 2; run++ {
		if _, err := pool.Exec(ctx, string(migration)); err != nil {
			t.Fatalf("migration run %d: %v", run, err)
		}
	}
	fairness, err := files.ReadFile("migrations/0038_add_unattached_cleanup_retry_schedule.sql")
	if err != nil {
		t.Fatal(err)
	}
	for run := 0; run < 2; run++ {
		if _, err := pool.Exec(ctx, string(fairness)); err != nil {
			t.Fatalf("retry migration run %d: %v", run, err)
		}
	}
	if _, err := pool.Exec(ctx, `UPDATE attachments SET state='DELETING' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	var attempts int
	if err := pool.QueryRow(ctx, `SELECT unattached_cleanup_attempts FROM attachments WHERE id=$1`, id).Scan(&attempts); err != nil || attempts != 0 {
		t.Fatalf("initial retry attempts = %d, error = %v", attempts, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE attachments SET state='ATTACHED' WHERE id=$1`, id); err == nil {
		t.Fatal("ATTACHED without attached_at should be rejected")
	}
}
