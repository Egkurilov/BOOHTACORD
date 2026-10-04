package observeusage

import (
	"context"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestPostgresDurableCountsRespectMoscowDaysAndRetention(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 4, 21, 5, 0, 0, time.UTC)
	a, b := "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"
	_, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role,created_at,blocked_at)
VALUES ($1,'alpha','A','test','MEMBER','2026-10-04 20:59:00+00',NULL),
       ($2,'bravo','B','test','MEMBER','2026-10-04 21:00:00+00',now()),
       ('00000000-0000-0000-0000-000000000003','admin','C','test','ADMINISTRATOR','2026-10-01 00:00:00+00',NULL)`, a, b)
	if err != nil {
		t.Fatal(err)
	}
	store := NewPostgres(pool)
	for _, event := range []struct {
		id string
		at time.Time
	}{
		{a, now.AddDate(0, 0, -33)}, {a, now.AddDate(0, 0, -1)}, {a, now}, {a, now}, {b, now},
	} {
		if err := store.Record(ctx, event.id, event.at); err != nil {
			t.Fatal(err)
		}
	}
	got, err := NewPostgres(pool).Snapshot(ctx, now)
	if err != nil {
		t.Fatal(err)
	}
	if got.Users != 3 || got.RegistrationsToday != 1 || got.RegistrationsYesterday != 1 || got.ActiveToday != 2 || got.ActiveYesterday != 1 {
		t.Fatalf("incorrect persisted aggregate: %+v", got)
	}
	var rows int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM user_daily_activity").Scan(&rows); err != nil || rows != 3 {
		t.Fatalf("retention or duplicate failed: %d %v", rows, err)
	}
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	again, err := store.Snapshot(ctx, now)
	if err != nil || !again.StartedAt.Equal(got.StartedAt) || again.ActiveToday != got.ActiveToday {
		t.Fatal("repeat migration reset collection")
	}
}
