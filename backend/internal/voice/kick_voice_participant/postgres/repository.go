package kickvoiceparticipantpostgres

import (
	"context"
	"fmt"

	kickvoiceparticipant "voice-platform/backend/internal/voice/kick_voice_participant"
)

const kickVoiceLease = `
WITH revoked AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'KICK'
    WHERE user_id = $1 AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, target_user_id, event_type, metadata)
    SELECT $2, $1, 'VOICE_LEASE_KICKED', jsonb_build_object('lease_id', id::text, 'channel_id', channel_id::text)
    FROM revoked
)
SELECT COUNT(*) FROM revoked`

type Row interface{ Scan(...any) error }
type Transaction interface {
	LockUser(context.Context, string) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Kick(context context.Context, input kickvoiceparticipant.Input) (kickvoiceparticipant.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return kickvoiceparticipant.Result{}, fmt.Errorf("begin voice kick: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.LockUser(context, input.TargetID); err != nil {
		return kickvoiceparticipant.Result{}, fmt.Errorf("lock voice account: %w", err)
	}
	var result kickvoiceparticipant.Result
	if err := transaction.QueryRow(context, kickVoiceLease, input.TargetID, input.ActorID).Scan(&result.RevokedLeases); err != nil {
		return kickvoiceparticipant.Result{}, fmt.Errorf("revoke voice lease: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return kickvoiceparticipant.Result{}, fmt.Errorf("commit voice kick: %w", err)
	}
	committed = true
	return result, nil
}
