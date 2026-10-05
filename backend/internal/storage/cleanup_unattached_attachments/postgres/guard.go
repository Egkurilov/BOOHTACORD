package cleanupunattachedattachmentspostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	cleanup "voice-platform/backend/internal/storage/cleanup_unattached_attachments"
)

// Keep the row/FK lock through the final link check and filesystem operation.
func (repository Repository) FinalizeWithFile(ctx context.Context, candidate cleanup.Candidate, remove func(string) error) error {
	includeDM, err := repository.hasDMLinks(ctx)
	if err != nil {
		return err
	}
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(context.Background())
	var key string
	err = tx.QueryRow(ctx, `SELECT storage_key::text FROM attachments WHERE id=$1 AND state='DELETING' FOR UPDATE`, candidate.ID).Scan(&key)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrFinalizationBlocked
	}
	if err != nil {
		return err
	}
	if key != candidate.Key {
		return ErrFinalizationBlocked
	}
	query := `SELECT EXISTS (SELECT 1 FROM message_attachments WHERE attachment_id=$1)`
	if includeDM {
		query += ` OR EXISTS (SELECT 1 FROM direct_message_attachments WHERE attachment_id=$1)`
	}
	var linked bool
	if err := tx.QueryRow(ctx, query, candidate.ID).Scan(&linked); err != nil {
		return err
	}
	if linked {
		return ErrFinalizationBlocked
	}
	if err := remove(key); err != nil {
		return err
	}
	tag, err := tx.Exec(ctx, finalizeStatement(includeDM), candidate.ID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() != 1 {
		return ErrFinalizationBlocked
	}
	return tx.Commit(ctx)
}
