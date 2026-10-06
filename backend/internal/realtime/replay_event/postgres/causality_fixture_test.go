package replayeventpostgres

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"testing"
)

func applyTraceMigration(t *testing.T, ctx context.Context, db *pgxpool.Pool) {
	t.Helper()
	if _, err := db.Exec(ctx, `CREATE TABLE voice_sfu_revocations(lease_id uuid PRIMARY KEY)`); err != nil {
		t.Fatal(err)
	}
	migration, err := os.ReadFile("../../../database/migrate/migrations/0047_add_trace_causality.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
}
