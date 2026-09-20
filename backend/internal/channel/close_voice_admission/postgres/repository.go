package closevoiceadmissionpostgres

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	closevoiceadmission "voice-platform/backend/internal/channel/close_voice_admission"
)

const topologyLockKey int64 = 441903817

const closeVoiceAdmission = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), changed AS (
    UPDATE channels
    SET admission_closed_at = now(), updated_at = now()
    WHERE id = $2 AND kind = 'VOICE' AND archived_at IS NULL AND admission_closed_at IS NULL
      AND EXISTS (SELECT 1 FROM state)
    RETURNING id
), revoked AS (
    UPDATE voice_leases
    SET revoked_at = now(), revocation_reason = 'CHANNEL_CLOSED'
    WHERE channel_id = (SELECT id FROM changed) AND revoked_at IS NULL
    RETURNING id, channel_id
), queued AS (
    INSERT INTO voice_sfu_revocations (lease_id, channel_id)
    SELECT id, channel_id FROM revoked
    ON CONFLICT (lease_id) DO NOTHING
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE AND revision = $1
      AND EXISTS (SELECT 1 FROM state) AND EXISTS (SELECT 1 FROM changed)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $3, 'VOICE_CHANNEL_ADMISSION_CLOSED',
        jsonb_build_object('channel_id', changed.id::text, 'revoked_leases', (SELECT COUNT(*) FROM revoked))
    FROM changed CROSS JOIN revised
)
SELECT changed.id::text, revised.revision, (SELECT COUNT(*) FROM revoked)
FROM changed CROSS JOIN revised`

type Row interface{ Scan(...any) error }
type Transaction interface {
	Lock(context.Context, int64) error
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Close(context context.Context, input closevoiceadmission.Input) (closevoiceadmission.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return closevoiceadmission.Result{}, fmt.Errorf("begin voice admission close: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return closevoiceadmission.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result closevoiceadmission.Result
	err = transaction.QueryRow(context, closeVoiceAdmission, input.ExpectedRevision, input.ChannelID, input.ActorID).Scan(&result.ID, &result.Revision, &result.RevokedLeases)
	if errors.Is(err, pgx.ErrNoRows) {
		return closevoiceadmission.Result{}, closevoiceadmission.ErrRevisionConflict
	}
	if err != nil {
		return closevoiceadmission.Result{}, fmt.Errorf("close voice admission: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return closevoiceadmission.Result{}, fmt.Errorf("commit voice admission close: %w", err)
	}
	committed = true
	return result, nil
}
