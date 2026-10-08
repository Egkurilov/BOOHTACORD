package managevoicetimeoutpostgres

import (
	"context"
	"time"
	causal "voice-platform/backend/internal/observability/causal_reference"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func (r Repository) Set(ctx context.Context, in timeout.Input) (timeout.State, error) {
	tx, err := r.begin(ctx, in, true)
	if err != nil {
		return timeout.State{}, err
	}
	defer tx.Rollback(ctx)
	var now time.Time
	if err = tx.QueryRow(ctx, `SELECT clock_timestamp()`).Scan(&now); err != nil {
		return timeout.State{}, err
	}
	if !in.ExpiresAt.After(now) || in.ExpiresAt.After(now.Add(24*time.Hour)) {
		return timeout.State{}, timeout.ErrInvalidInput
	}
	var revoked int
	if err = tx.QueryRow(ctx, setTimeout, in.TargetID, in.ActorID, in.ExpiresAt, in.Reason, causal.From(ctx).Bytes()).Scan(&revoked); err != nil {
		return timeout.State{}, err
	}
	state, err := readState(ctx, tx, in.TargetID)
	if err != nil {
		return timeout.State{}, err
	}
	state.RevokedLeases = revoked
	return state, tx.Commit(ctx)
}

const setTimeout = `WITH changed AS (
 INSERT INTO voice_timeouts(user_id,updated_by,expires_at,reason_code) VALUES($1,$2,$3,$4)
 ON CONFLICT(user_id) DO UPDATE SET updated_by=$2,expires_at=$3,reason_code=$4,updated_at=clock_timestamp()
 WHERE (voice_timeouts.expires_at,voice_timeouts.reason_code) IS DISTINCT FROM ($3::timestamptz,$4::text)
 RETURNING user_id
), revoked AS (
 UPDATE voice_leases SET revoked_at=clock_timestamp(),revocation_reason='KICK'
 WHERE user_id=$1 AND revoked_at IS NULL RETURNING id,channel_id
), queued AS (
 INSERT INTO voice_sfu_revocations(lease_id,channel_id,trace_cause)
 SELECT id,channel_id,$5::jsonb FROM revoked ON CONFLICT(lease_id) DO NOTHING
), audited AS (
 INSERT INTO audit_events(actor_user_id,target_user_id,event_type,metadata)
 SELECT $2,$1,'VOICE_TIMEOUT_SET',jsonb_build_object('expires_at',$3::timestamptz,'reason_code',$4::text)
 FROM changed
) SELECT COUNT(*) FROM revoked`
