package recoverlastadministratoraccesspostgres

import (
	"context"
	"crypto/sha256"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

func newRecoveryPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	if address := net.ParseIP(config.ConnConfig.Host); address == nil || !address.IsLoopback() {
		t.Fatal("test database must use a loopback IP address")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	admin, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal(err)
	}
	schema := "qa02_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal(err)
	}
	isolated := config.Copy()
	if isolated.ConnConfig.RuntimeParams == nil {
		isolated.ConnConfig.RuntimeParams = map[string]string{}
	}
	isolated.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, isolated)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanup, done := context.WithTimeout(context.Background(), 10*time.Second)
		defer done()
		_, _ = admin.Exec(cleanup, "DROP SCHEMA "+schema+" CASCADE")
		admin.Close()
	})
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	return pool
}

func seedRecoveryAccess(t *testing.T, pool *pgxpool.Pool, userID string) (string, [sha256.Size]byte) {
	t.Helper()
	ctx := context.Background()
	categoryID, channelID, leaseID := uuid.NewString(), uuid.NewString(), uuid.NewString()
	digest := sha256.Sum256([]byte("synthetic recovery session"))
	for _, fixture := range []struct {
		statement string
		args      []any
	}{
		{`INSERT INTO sessions (token_digest, user_id) VALUES ($1, $2)`, []any{digest[:], userID}},
		{`INSERT INTO categories (id, name, position) VALUES ($1, 'QA recovery', 0)`, []any{categoryID}},
		{`INSERT INTO channels (id, category_id, name, kind, position) VALUES ($1, $2, 'QA voice', 'VOICE', 0)`, []any{channelID, categoryID}},
		{`INSERT INTO voice_leases (id, user_id, channel_id, session_token_digest) VALUES ($1, $2, $3, $4)`, []any{leaseID, userID, channelID, digest[:]}},
	} {
		if _, err := pool.Exec(ctx, fixture.statement, fixture.args...); err != nil {
			t.Fatal(err)
		}
	}
	return leaseID, digest
}
