package inspectattachmentcleanup

import (
	"context"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
)

type Inspector struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Inspector { return Inspector{pool: pool} }

func (i Inspector) Database(ctx context.Context, kind string, now time.Time) (Report, error) {
	if (kind != "UNATTACHED" && kind != "HIDDEN") || now.IsZero() {
		return Report{}, ErrInvalid
	}
	tx, err := i.pool.BeginTx(ctx, pgx.TxOptions{AccessMode: pgx.ReadOnly})
	if err != nil {
		return Report{}, err
	}
	defer tx.Rollback(context.Background())
	rows, err := tx.Query(ctx, reportSQL, kind, now)
	if err != nil {
		return Report{}, err
	}
	defer rows.Close()
	report := empty()
	for rows.Next() {
		var reason string
		var totals Totals
		var age float64
		if err := rows.Scan(&reason, &totals.Count, &totals.Bytes, &age); err != nil {
			return Report{}, err
		}
		if reason == "eligible" {
			report.Eligible = totals
		} else {
			report.Skipped[reason] = totals
		}
		if age > report.OldestRetrySeconds {
			report.OldestRetrySeconds = age
		}
	}
	if err := rows.Err(); err != nil {
		return Report{}, err
	}
	return report, nil
}
