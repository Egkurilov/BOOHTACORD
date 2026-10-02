package postgres

import (
	"context"
	"testing"
	"time"
)

func TestIsolatedSchemasAreDistinctAndCleanupSurvivesCancelledContext(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	observer := New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", LoopbackIP)
	var schemas []string
	t.Run("owned schemas", func(t *testing.T) {
		ownedContext, stop := context.WithCancel(ctx)
		first := New(t, ownedContext, "VOICE_PLATFORM_TEST_DATABASE_URL", LoopbackIP)
		second := New(t, ownedContext, "VOICE_PLATFORM_TEST_DATABASE_URL", LoopbackIP)
		var one, two string
		if err := first.QueryRow(ctx, "SELECT current_schema()").Scan(&one); err != nil {
			t.Fatal(err)
		}
		if err := second.QueryRow(ctx, "SELECT current_schema()").Scan(&two); err != nil {
			t.Fatal(err)
		}
		if one == two {
			t.Fatal("fixtures share a schema")
		}
		if _, err := first.Exec(ctx, "CREATE TABLE marker (value int)"); err != nil {
			t.Fatal(err)
		}
		var visible bool
		if err := second.QueryRow(ctx, "SELECT to_regclass('marker') IS NOT NULL").Scan(&visible); err != nil || visible {
			t.Fatalf("another fixture's table is visible: %v, %v", visible, err)
		}
		schemas = []string{one, two}
		stop()
	})
	for _, schema := range schemas {
		var exists bool
		if err := observer.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname=$1)", schema).Scan(&exists); err != nil || exists {
			t.Fatalf("schema survived cleanup: %v, %v", exists, err)
		}
	}
}
