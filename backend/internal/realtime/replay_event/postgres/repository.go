package replayeventpostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const Retention = 7 * 24 * time.Hour
const ReplayLimit = 512

var (
	ErrInvalidCursor  = errors.New("invalid realtime cursor")
	ErrExpiredCursor  = errors.New("expired realtime cursor")
	ErrDifferentEpoch = errors.New("realtime cursor belongs to another server epoch")
	ErrReplayOverflow = errors.New("too many realtime events to replay")
)

type Database interface {
	Begin(context.Context) (pgx.Tx, error)
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
	QueryRow(context.Context, string, ...any) pgx.Row
	Query(context.Context, string, ...any) (pgx.Rows, error)
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Append(ctx context.Context, event eventhub.Event, recipients []string, epoch string) error {
	if err := validateHint(event, recipients); err != nil {
		return err
	}
	if _, err := uuid.Parse(epoch); err != nil {
		return ErrInvalidHint
	}
	payload, err := json.Marshal(event.Payload)
	if err != nil {
		return fmt.Errorf("encode realtime hint: %w", err)
	}
	var targetIDs []string
	if len(recipients) > 0 {
		targetIDs = recipients
	}
	tx, err := repository.database.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin realtime hint append: %w", err)
	}
	defer tx.Rollback(context.Background())
	// Identity sequence allocation must happen only after the prior append has
	// committed, otherwise seq=2 can become visible before seq=1 and a cursor
	// at seq=2 would permanently skip the later commit.
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock('realtime_events'::regclass::oid::bigint)`); err != nil {
		return fmt.Errorf("serialize realtime hint append: %w", err)
	}
	_, err = tx.Exec(ctx, `INSERT INTO realtime_events
    (id, boot_epoch, kind, occurred_at, payload, recipient_ids, trace_cause)
    VALUES ($1::uuid, $2::uuid, $3, $4, $5::jsonb, $6::text[]::uuid[], $7::jsonb)
    ON CONFLICT (id) DO NOTHING`, event.EventID, epoch, event.Kind, event.OccurredAt, payload, targetIDs, event.Cause.Bytes())
	if err != nil {
		return fmt.Errorf("append realtime hint: %w", err)
	}
	_, err = tx.Exec(ctx, `DELETE FROM realtime_events WHERE sequence IN (
    SELECT sequence FROM realtime_events WHERE stored_at < clock_timestamp() - interval '7 days'
    ORDER BY stored_at, sequence LIMIT 64)`)
	if err != nil {
		return fmt.Errorf("prune expired realtime hints: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit realtime hint append: %w", err)
	}
	return nil
}
