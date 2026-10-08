package managevoicetimeoutpostgres

import (
	"context"
	timeout "voice-platform/backend/internal/voice/manage_voice_timeout"
)

func (r Repository) Clear(ctx context.Context, in timeout.Input) (timeout.State, error) {
	tx, err := r.begin(ctx, in, true)
	if err != nil {
		return timeout.State{}, err
	}
	defer tx.Rollback(ctx)
	_, err = tx.Exec(ctx, `WITH cleared AS (DELETE FROM voice_timeouts WHERE user_id=$1 RETURNING user_id)
 INSERT INTO audit_events(actor_user_id,target_user_id,event_type,metadata)
 SELECT $2,$1,'VOICE_TIMEOUT_CLEARED','{}'::jsonb FROM cleared`, in.TargetID, in.ActorID)
	if err != nil {
		return timeout.State{}, err
	}
	state, err := readState(ctx, tx, in.TargetID)
	if err != nil {
		return timeout.State{}, err
	}
	return state, tx.Commit(ctx)
}
