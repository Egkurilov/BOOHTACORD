package cleanupunattachedattachmentspostgres

import (
	"context"
	"errors"
	"fmt"

	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

var ErrFinalizationBlocked = errors.New("claimed attachment could not be finalized")

func (repository Repository) Finalize(ctx context.Context, id string) error {
	includeDM, err := repository.hasDMLinks(ctx)
	if err != nil {
		return err
	}
	tag, err := repository.pool.Exec(ctx, finalizeStatement(includeDM), id)
	if err != nil {
		return fmt.Errorf("finalize claimed attachment: %w", err)
	}
	if tag.RowsAffected() != 1 {
		return ErrFinalizationBlocked
	}
	return nil
}

func finalizeStatement(includeDM bool) string {
	return `WITH deleted AS (
DELETE FROM attachments AS attachment
WHERE attachment.id = $1
  AND attachment.state = 'DELETING'
  AND NOT EXISTS (SELECT 1 FROM message_attachments AS link WHERE link.attachment_id = attachment.id)
` + dmLinkGuard(includeDM) + `
RETURNING 1
)
INSERT INTO audit_events (event_type, metadata)
SELECT 'UNATTACHED_ATTACHMENT_REMOVED', '{"removed":1}'::jsonb FROM deleted`
}

func (repository Repository) Exists(ctx context.Context, key string) (bool, error) {
	var exists bool
	err := repository.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM attachments WHERE storage_key = $1)`, key).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check attachment metadata: %w", err)
	}
	return exists, nil
}

func (repository Repository) Audit(ctx context.Context, result cleanup.Result) error {
	_, err := repository.pool.Exec(ctx, `INSERT INTO audit_events (event_type, metadata)
VALUES ('UNATTACHED_CLEANUP', jsonb_build_object(
    'claimed', $1::int, 'removed', $2::int, 'failed', $3::int, 'orphan_removed', $4::int))`,
		result.Claimed, result.Removed, result.Failed, result.OrphanRemoved)
	if err != nil {
		return fmt.Errorf("write cleanup audit counts: %w", err)
	}
	return nil
}
