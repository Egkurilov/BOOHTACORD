package adminpostgres

import (
	"context"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
)

type adminFixture struct {
	pool          *pgxpool.Pool
	first, second string
}

func newAdminFixture(t *testing.T) adminFixture {
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
	fixture := adminFixture{pool: pool, first: uuid.NewString(), second: uuid.NewString()}
	for _, seed := range []struct{ id, login string }{{fixture.first, "qa02first"}, {fixture.second, "qa02second"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id,login,display_name,password_hash,role) VALUES ($1,$2,'Administrator','test','ADMINISTRATOR')`, seed.id, seed.login); err != nil {
			t.Fatal(err)
		}
	}
	return fixture
}
