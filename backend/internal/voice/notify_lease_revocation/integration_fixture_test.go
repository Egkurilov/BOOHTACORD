package notifyleaserevocation

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

func newNotificationTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	databaseURL := os.Getenv("VOICE_PLATFORM_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("VOICE_PLATFORM_TEST_DATABASE_URL is not configured")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatal("parse test database URL:", err)
	}
	if address := net.ParseIP(config.ConnConfig.Host); address == nil || !address.IsLoopback() {
		t.Fatal("test database must use a loopback IP address")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	admin, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal("open test database:", err)
	}
	if err := admin.Ping(ctx); err != nil {
		admin.Close()
		t.Fatal("ping test database:", err)
	}
	schema := "voice_it_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := admin.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		admin.Close()
		t.Fatal("create test schema:", err)
	}
	isolated := config.Copy()
	if isolated.ConnConfig.RuntimeParams == nil {
		isolated.ConnConfig.RuntimeParams = make(map[string]string)
	}
	isolated.ConnConfig.RuntimeParams["search_path"] = schema
	pool, err := pgxpool.NewWithConfig(ctx, isolated)
	if err != nil {
		_, _ = admin.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE")
		admin.Close()
		t.Fatal("open isolated database:", err)
	}
	t.Cleanup(func() {
		pool.Close()
		cleanupContext, cleanupCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cleanupCancel()
		if _, err := admin.Exec(cleanupContext, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Errorf("drop test schema: %v", err)
		}
		admin.Close()
	})
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal("run migrations:", err)
	}
	return pool
}
