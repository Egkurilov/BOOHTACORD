package replayeventpostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	causal "voice-platform/backend/internal/observability/causal_reference"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func (repository Repository) Replay(ctx context.Context, accountID, after, epoch string, limit int) ([]eventhub.Event, error) {
	if _, err := uuid.Parse(accountID); err != nil {
		return nil, ErrInvalidCursor
	}
	if _, err := uuid.Parse(after); err != nil {
		return nil, ErrInvalidCursor
	}
	var sequence int64
	var cursorEpoch string
	var expired bool
	var recipients []string
	err := repository.database.QueryRow(ctx, `SELECT sequence, boot_epoch::text,
    stored_at < clock_timestamp() - interval '7 days', recipient_ids::text[]
    FROM realtime_events WHERE id = $1::uuid`, after).Scan(&sequence, &cursorEpoch, &expired, &recipients)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrInvalidCursor
	}
	if err != nil {
		return nil, fmt.Errorf("load realtime cursor: %w", err)
	}
	if cursorEpoch != epoch {
		return nil, ErrDifferentEpoch
	}
	if expired {
		return nil, ErrExpiredCursor
	}
	if recipients != nil && !contains(recipients, accountID) {
		return nil, ErrInvalidCursor
	}
	if limit < 1 || limit > ReplayLimit {
		limit = ReplayLimit
	}
	rows, err := repository.database.Query(ctx, `SELECT id::text, kind, occurred_at, payload, trace_cause
    FROM realtime_events
    WHERE sequence > $1 AND boot_epoch = $2::uuid
      AND stored_at >= clock_timestamp() - interval '7 days'
      AND (recipient_ids IS NULL OR $3::uuid = ANY(recipient_ids))
    ORDER BY sequence LIMIT $4`, sequence, epoch, accountID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("query realtime replay: %w", err)
	}
	defer rows.Close()
	events := make([]eventhub.Event, 0, limit)
	for rows.Next() {
		var event eventhub.Event
		var payload []byte
		var cause []byte
		if err := rows.Scan(&event.EventID, &event.Kind, &event.OccurredAt, &payload, &cause); err != nil {
			return nil, fmt.Errorf("scan realtime replay: %w", err)
		}
		event.Cause = causal.Decode(cause)
		if err := json.Unmarshal(payload, &event.Payload); err != nil {
			return nil, fmt.Errorf("decode realtime replay: %w", err)
		}
		events = append(events, event)
		if len(events) > limit {
			return nil, ErrReplayOverflow
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("read realtime replay: %w", err)
	}
	return events, nil
}

func contains(values []string, wanted string) bool {
	for _, value := range values {
		if value == wanted {
			return true
		}
	}
	return false
}
