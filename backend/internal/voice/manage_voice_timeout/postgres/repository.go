package managevoicetimeoutpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"sort"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }

func (r Repository) begin(ctx context.Context, in timeout.Input, admin bool) (pgx.Tx, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	fail := func(err error) (pgx.Tx, error) { _ = tx.Rollback(ctx); return nil, err }
	ids := []string{in.ActorID, in.TargetID}
	sort.Strings(ids)
	for _, id := range ids {
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, id); err != nil {
			return fail(err)
		}
	}
	var role string
	err = tx.QueryRow(ctx, `SELECT account.role FROM users account
 JOIN sessions session ON session.user_id=account.id
 WHERE account.id=$1 AND session.token_digest=$2 AND session.revoked_at IS NULL
 AND account.blocked_at IS NULL FOR SHARE OF account,session`, in.ActorID, in.SessionDigest[:]).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return fail(timeout.ErrUnauthenticated)
	}
	if err != nil {
		return fail(err)
	}
	if (admin || in.ActorID != in.TargetID) && role != "ADMINISTRATOR" {
		return fail(timeout.ErrForbidden)
	}
	var exists int
	err = tx.QueryRow(ctx, `SELECT 1 FROM users WHERE id=$1 FOR SHARE`, in.TargetID).Scan(&exists)
	if errors.Is(err, pgx.ErrNoRows) {
		return fail(timeout.ErrNotFound)
	}
	if err != nil {
		return fail(err)
	}
	return tx, nil
}
