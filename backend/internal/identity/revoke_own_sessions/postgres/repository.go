package revokesessionpostgres

import (
	"context"
	_ "embed"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
)

//go:embed revoke.sql
var revokeSQL string

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }

func (r Repository) Revoke(ctx context.Context, input revoke.Input) (revoke.Result, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return revoke.Result{}, err
	}
	defer tx.Rollback(ctx)
	var owner string
	err = tx.QueryRow(ctx, `SELECT id::text FROM users WHERE id=$1::uuid AND blocked_at IS NULL FOR UPDATE`, input.AccountID).Scan(&owner)
	if errors.Is(err, pgx.ErrNoRows) {
		return revoke.Result{}, revoke.ErrUnauthenticated
	}
	if err != nil {
		return revoke.Result{}, err
	}
	var active bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM sessions WHERE user_id=$1::uuid
        AND token_digest=$2 AND revoked_at IS NULL)`, input.AccountID, input.Current[:]).Scan(&active)
	if err != nil {
		return revoke.Result{}, err
	}
	if !active {
		return revoke.Result{}, revoke.ErrUnauthenticated
	}
	var handle any
	if input.SessionID != "" {
		handle = input.SessionID
	}
	var result revoke.Result
	err = tx.QueryRow(ctx, revokeSQL, input.AccountID, input.Current[:], handle, input.Others).Scan(&result.Count, &result.CurrentRevoked)
	if err != nil {
		return result, err
	}
	if !input.Others && result.Count == 0 {
		return result, revoke.ErrNotFound
	}
	return result, tx.Commit(ctx)
}
