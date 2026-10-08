package managevoicetimeoutpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func (r Repository) Read(ctx context.Context, in timeout.Input) (timeout.State, error) {
	tx, err := r.begin(ctx, in, false)
	if err != nil {
		return timeout.State{}, err
	}
	defer tx.Rollback(ctx)
	state, err := readState(ctx, tx, in.TargetID)
	if err != nil {
		return timeout.State{}, err
	}
	return state, tx.Commit(ctx)
}
func readState(ctx context.Context, tx pgx.Tx, target string) (timeout.State, error) {
	var state timeout.State
	var expiry time.Time
	err := tx.QueryRow(ctx, `SELECT expires_at,reason_code FROM voice_timeouts
 WHERE user_id=$1 AND expires_at>clock_timestamp()`, target).Scan(&expiry, &state.Reason)
	if err == nil {
		state.Active = true
		state.ExpiresAt = &expiry
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return state, err
	}
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM voice_sfu_revocations work
 JOIN voice_leases lease ON lease.id=work.lease_id
 WHERE lease.user_id=$1 AND work.completed_at IS NULL)`, target).Scan(&state.RevocationPending)
	return state, err
}
