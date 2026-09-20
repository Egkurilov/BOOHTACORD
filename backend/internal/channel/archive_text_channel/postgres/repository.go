package archivepostgres

import (
	"context"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/channel/archive_text_channel"
)

const topologyLockKey int64 = 441903817

const archiveTextChannel = `
WITH state AS (
    SELECT revision FROM channel_topology_state
    WHERE singleton = TRUE AND revision = $1
), changed AS (
    UPDATE channels
    SET archived_at = now(), updated_at = now()
    WHERE id = $2
      AND kind = 'TEXT'
      AND archived_at IS NULL
      AND EXISTS (SELECT 1 FROM state)
    RETURNING id
), revised AS (
    UPDATE channel_topology_state
    SET revision = revision + 1
    WHERE singleton = TRUE
      AND revision = $1
      AND EXISTS (SELECT 1 FROM state)
      AND EXISTS (SELECT 1 FROM changed)
    RETURNING revision
), audited AS (
    INSERT INTO audit_events (actor_user_id, event_type, metadata)
    SELECT $3, 'TEXT_CHANNEL_ARCHIVED', jsonb_build_object('channel_id', id::text)
    FROM changed CROSS JOIN revised
)
SELECT changed.id::text, revised.revision FROM changed CROSS JOIN revised`

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

func (repository Repository) Archive(context context.Context, input archivetextchannel.Input) (archivetextchannel.Result, error) {
	transaction, err := repository.database.Begin(context)
	if err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("begin text channel archive: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(context)
		}
	}()
	if err := transaction.Lock(context, topologyLockKey); err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("lock channel topology: %w", err)
	}
	var result archivetextchannel.Result
	err = transaction.QueryRow(context, archiveTextChannel, input.ExpectedRevision, input.ChannelID, input.ActorID).Scan(&result.ID, &result.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return archivetextchannel.Result{}, archivetextchannel.ErrRevisionConflict
	}
	if err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("archive text channel: %w", err)
	}
	if err := transaction.Commit(context); err != nil {
		return archivetextchannel.Result{}, fmt.Errorf("commit text channel archive: %w", err)
	}
	committed = true
	return result, nil
}
