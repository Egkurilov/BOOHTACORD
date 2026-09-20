package dispatchvoicesfurevocation

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
)

var ErrInvalidClaimLimit = errors.New("invalid voice sfu revocation claim limit")

const claimPending = `
WITH candidates AS (
    SELECT lease_id
    FROM voice_sfu_revocations
    WHERE completed_at IS NULL
      AND next_attempt_at <= now()
      AND (claim_token IS NULL OR claimed_at < now() - interval '30 seconds')
    ORDER BY requested_at, lease_id
    LIMIT $1
    FOR UPDATE SKIP LOCKED
), claimed AS (
    UPDATE voice_sfu_revocations AS revocation
    SET claim_token = $2::uuid,
        claimed_at = now(),
        attempt_count = attempt_count + 1
    FROM candidates
    WHERE revocation.lease_id = candidates.lease_id
    RETURNING revocation.lease_id::text, revocation.channel_id::text
)
SELECT lease_id, channel_id FROM claimed`

const confirmClaim = `
UPDATE voice_sfu_revocations
SET completed_at = now(),
    claim_token = NULL,
    claimed_at = NULL,
    last_error_code = NULL
WHERE lease_id = $1 AND claim_token = $2::uuid AND completed_at IS NULL`

const retryClaim = `
UPDATE voice_sfu_revocations
SET claim_token = NULL,
    claimed_at = NULL,
    next_attempt_at = now() + interval '15 seconds',
    last_error_code = $3
WHERE lease_id = $1 AND claim_token = $2::uuid AND completed_at IS NULL`

type Item struct{ LeaseID, ChannelID, ClaimToken string }

type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}

type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
	Exec(context.Context, string, ...any) error
}

type Repository struct{ database Database }

func NewRepository(database Database) Repository { return Repository{database: database} }

func (repository Repository) Claim(context context.Context, limit int) ([]Item, error) {
	if limit < 1 || limit > 100 {
		return nil, ErrInvalidClaimLimit
	}
	claimToken := uuid.NewString()
	rows, err := repository.database.Query(context, claimPending, limit, claimToken)
	if err != nil {
		return nil, fmt.Errorf("claim pending voice sfu revocations: %w", err)
	}
	defer rows.Close()
	items := make([]Item, 0, limit)
	for rows.Next() {
		item := Item{ClaimToken: claimToken}
		if err := rows.Scan(&item.LeaseID, &item.ChannelID); err != nil {
			return nil, fmt.Errorf("scan claimed voice sfu revocation: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate claimed voice sfu revocations: %w", err)
	}
	return items, nil
}

func (repository Repository) Confirm(context context.Context, item Item) error {
	if err := repository.database.Exec(context, confirmClaim, item.LeaseID, item.ClaimToken); err != nil {
		return fmt.Errorf("confirm voice sfu revocation: %w", err)
	}
	return nil
}

func (repository Repository) Retry(context context.Context, item Item, code string) error {
	if err := repository.database.Exec(context, retryClaim, item.LeaseID, item.ClaimToken, code); err != nil {
		return fmt.Errorf("retry voice sfu revocation: %w", err)
	}
	return nil
}
