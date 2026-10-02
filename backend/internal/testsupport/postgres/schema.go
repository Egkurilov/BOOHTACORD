package postgres

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New creates a unique empty schema. Callers retain migration and seed ownership.
// An absent DSN is a visible skip; the native release gate rejects every skip.
func New(t testing.TB, ctx context.Context, environment string, policy HostPolicy) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv(environment)
	if dsn == "" {
		t.Skip(environment + " is not configured")
	}
	base, err := config(dsn, policy)
	if err != nil {
		t.Fatal(err)
	}
	admin, err := pgxpool.NewWithConfig(ctx, base)
	if err != nil {
		t.Fatal("open disposable test database:", err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal("ping disposable test database:", err)
	}
	schema := "voice_it_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	identifier := pgx.Identifier{schema}.Sanitize()
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+identifier); err != nil {
		admin.Close()
		t.Fatal("create isolated schema:", err)
	}
	var pool *pgxpool.Pool
	t.Cleanup(func() {
		if pool != nil {
			pool.Close()
		}
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		defer admin.Close()
		if _, err := admin.Exec(cleanup, "DROP SCHEMA "+identifier+" CASCADE"); err != nil {
			t.Errorf("drop isolated test schema: %v", err)
		}
	})
	isolated := base.Copy()
	if isolated.ConnConfig.RuntimeParams == nil {
		isolated.ConnConfig.RuntimeParams = map[string]string{}
	}
	isolated.ConnConfig.RuntimeParams["search_path"] = schema
	isolated.ConnConfig.RuntimeParams["application_name"] = schema
	pool, err = pgxpool.NewWithConfig(ctx, isolated)
	if err != nil {
		t.Fatal("open isolated test pool:", err)
	}
	return pool
}
