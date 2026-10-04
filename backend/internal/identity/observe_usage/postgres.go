package observeusage

import (
	"context"
	_ "embed"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"time"
)

//go:embed snapshot.sql
var snapshotSQL string

type Database interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

type Postgres struct{ database Database }

func NewPostgres(database Database) Postgres { return Postgres{database: database} }

func (p Postgres) Record(ctx context.Context, account string, now time.Time) error {
	_, err := p.database.Exec(ctx, `
WITH pruned AS (DELETE FROM user_daily_activity WHERE activity_day < $1::date - 32)
INSERT INTO user_daily_activity(activity_day, user_id) VALUES ($1::date, $2::uuid)
ON CONFLICT (activity_day, user_id) DO NOTHING`, Day(now).Format("2006-01-02"), account)
	return err
}

func (p Postgres) Snapshot(ctx context.Context, now time.Time) (Snapshot, error) {
	var result Snapshot
	err := p.database.QueryRow(ctx, snapshotSQL, Day(now), Day(now).AddDate(0, 0, -1), now).Scan(
		&result.Users, &result.RegistrationsToday, &result.RegistrationsYesterday,
		&result.ActiveToday, &result.ActiveYesterday, &result.StartedAt)
	return result, err
}
