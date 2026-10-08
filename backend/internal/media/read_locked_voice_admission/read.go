package readlockedvoiceadmission

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Row keeps adapter interfaces stable while serializing admission with moderation.
type Row struct {
	Pool                          *pgxpool.Pool
	Context                       context.Context
	AccountID, LeaseID, Statement string
	Arguments                     []any
}

func ForAccount(pool *pgxpool.Pool, ctx context.Context, account, statement string, args ...any) Row {
	return Row{Pool: pool, Context: ctx, AccountID: account, Statement: statement, Arguments: args}
}
func ForLease(pool *pgxpool.Pool, ctx context.Context, lease, statement string, args ...any) Row {
	return Row{Pool: pool, Context: ctx, LeaseID: lease, Statement: statement, Arguments: args}
}
func (r Row) Scan(destinations ...any) error {
	tx, err := r.Pool.Begin(r.Context)
	if err != nil {
		return err
	}
	defer tx.Rollback(r.Context)
	account := r.AccountID
	if account == "" {
		if err = tx.QueryRow(r.Context, `SELECT user_id::text FROM voice_leases WHERE id=$1`, r.LeaseID).Scan(&account); err != nil {
			return err
		}
	}
	if _, err = tx.Exec(r.Context, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, account); err != nil {
		return err
	}
	// A fresh READ COMMITTED statement sees moderation that completed while waiting.
	if err = tx.QueryRow(r.Context, r.Statement, r.Arguments...).Scan(destinations...); err != nil {
		return err
	}
	return tx.Commit(r.Context)
}
