package releasevoiceleasepostgres

import (
	"context"
	"fmt"

	releasevoicelease "voice-platform/backend/internal/voice/release_voice_lease"
)

const releaseLease = `
WITH revoked AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'VOLUNTARY_LEAVE'
    WHERE id = $1 AND user_id = $2 AND session_token_digest = $3 AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked
    ON CONFLICT (lease_id) DO NOTHING
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $2, 'VOICE_LEASE_RELEASED', jsonb_build_object('lease_id', id::text, 'channel_id', channel_id::text)
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

func (repository Repository) Release(context context.Context, input releasevoicelease.Input) error {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return fmt.Errorf("begin voice lease release: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.LockUser(context, input.ActorID); err != nil {
		return fmt.Errorf("lock voice account: %w", err)
	}
	var released int64
	if err := transaction.QueryRow(context, releaseLease, input.LeaseID, input.ActorID, input.SessionDigest[:]).Scan(&released); err != nil {
		return fmt.Errorf("release voice lease: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return fmt.Errorf("commit voice lease release: %w", err)
	}
	committed = true
	return nil
}
