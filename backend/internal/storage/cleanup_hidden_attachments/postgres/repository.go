package cleanuphiddenattachmentspostgres

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	cleanup "voice-platform/backend/internal/storage/cleanup_hidden_attachments"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }

const noLiveLinks = `
  AND NOT EXISTS (
    SELECT 1 FROM message_attachments link
    JOIN messages message ON message.id = link.message_id
    WHERE link.attachment_id = attachment.id AND message.deleted_at IS NULL
  )
  AND NOT EXISTS (
    SELECT 1 FROM direct_message_attachments link
    JOIN direct_message_messages message ON message.id = link.message_id
    WHERE link.attachment_id = attachment.id AND message.deleted_at IS NULL
  )`

const claimStatement = `WITH eligible AS (
  SELECT attachment.id FROM attachments attachment
  WHERE (
    attachment.state = 'HIDDEN' OR
    (attachment.state = 'ATTACHED' AND (
      EXISTS (SELECT 1 FROM message_attachments link JOIN messages message ON message.id = link.message_id WHERE link.attachment_id = attachment.id AND message.deleted_at IS NOT NULL) OR
      EXISTS (SELECT 1 FROM direct_message_attachments link JOIN direct_message_messages message ON message.id = link.message_id WHERE link.attachment_id = attachment.id AND message.deleted_at IS NOT NULL)
    ))
  )
  AND (attachment.hidden_cleanup_claim_token IS NULL OR attachment.hidden_cleanup_claimed_at < $1::timestamptz - interval '5 minutes')
` + noLiveLinks + `
  ORDER BY attachment.hidden_cleanup_claimed_at NULLS FIRST,
           COALESCE(attachment.hidden_at, attachment.created_at), attachment.id
  LIMIT $2 FOR UPDATE OF attachment SKIP LOCKED
)
UPDATE attachments attachment SET
  state = 'HIDDEN', hidden_at = COALESCE(attachment.hidden_at, $1),
  hidden_cleanup_claim_token = $3, hidden_cleanup_claimed_at = $1
FROM eligible WHERE attachment.id = eligible.id
RETURNING attachment.id::text, attachment.storage_key::text, attachment.hidden_cleanup_claim_token::text`

func (repository Repository) Claim(ctx context.Context, now time.Time, limit int) ([]cleanup.Candidate, error) {
	token := uuid.NewString()
	rows, err := repository.pool.Query(ctx, claimStatement, now, limit, token)
	if err != nil {
		return nil, fmt.Errorf("claim hidden attachment rows: %w", err)
	}
	defer rows.Close()
	var candidates []cleanup.Candidate
	for rows.Next() {
		var candidate cleanup.Candidate
		if err := rows.Scan(&candidate.ID, &candidate.Key, &candidate.Token); err != nil {
			return nil, err
		}
		candidates = append(candidates, candidate)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("read hidden attachment claims: %w", err)
	}
	return candidates, nil
}

func (repository Repository) Audit(ctx context.Context, result cleanup.Result) error {
	_, err := repository.pool.Exec(ctx, `INSERT INTO audit_events (event_type,metadata)
VALUES ('HIDDEN_ATTACHMENT_CLEANUP',jsonb_build_object('claimed',$1::int,'removed',$2::int,'failed',$3::int))`, result.Claimed, result.Removed, result.Failed)
	if err != nil {
		return fmt.Errorf("write hidden attachment cleanup audit: %w", err)
	}
	return nil
}
