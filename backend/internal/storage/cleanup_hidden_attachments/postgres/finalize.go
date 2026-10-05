package cleanuphiddenattachmentspostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	cleanup "voice-platform/backend/internal/storage/cleanup_hidden_attachments"
)

var ErrFinalizationBlocked = errors.New("hidden attachment finalization blocked")

const liveLinkStatement = `SELECT
  EXISTS (SELECT 1 FROM message_attachments link JOIN messages message ON message.id=link.message_id
          WHERE link.attachment_id=$1 AND message.deleted_at IS NULL)
  OR EXISTS (SELECT 1 FROM direct_message_attachments link JOIN direct_message_messages message ON message.id=link.message_id
             WHERE link.attachment_id=$1 AND message.deleted_at IS NULL)`

func (repository Repository) Finalize(ctx context.Context, candidate cleanup.Candidate) error {
	return repository.FinalizeWithFile(ctx, candidate, nil)
}

func (repository Repository) FinalizeWithFile(ctx context.Context, candidate cleanup.Candidate, remove func(string) error) error {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin hidden attachment finalization: %w", err)
	}
	defer tx.Rollback(context.Background())
	var id, key string
	err = tx.QueryRow(ctx, `SELECT id::text,storage_key::text FROM attachments WHERE id=$1 AND state='HIDDEN' AND hidden_cleanup_claim_token=$2 FOR UPDATE`, candidate.ID, candidate.Token).Scan(&id, &key)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrFinalizationBlocked
	}
	if err != nil {
		return fmt.Errorf("lock hidden attachment: %w", err)
	}
	var live bool
	if err := tx.QueryRow(ctx, liveLinkStatement, id).Scan(&live); err != nil {
		return fmt.Errorf("recheck live attachment links: %w", err)
	}
	if live {
		return ErrFinalizationBlocked
	}
	if remove != nil {
		if candidate.Key != key {
			return ErrFinalizationBlocked
		}
		if err := remove(key); err != nil {
			return err
		}
	}
	textLinks, err := tx.Exec(ctx, `DELETE FROM message_attachments WHERE attachment_id=$1`, id)
	if err != nil {
		return fmt.Errorf("remove hidden text links: %w", err)
	}
	dmLinks, err := tx.Exec(ctx, `DELETE FROM direct_message_attachments WHERE attachment_id=$1`, id)
	if err != nil {
		return fmt.Errorf("remove hidden direct-message links: %w", err)
	}
	tag, err := tx.Exec(ctx, `DELETE FROM attachments WHERE id=$1 AND state='HIDDEN' AND hidden_cleanup_claim_token=$2`, id, candidate.Token)
	if err != nil {
		return fmt.Errorf("remove hidden attachment metadata: %w", err)
	}
	if tag.RowsAffected() != 1 {
		return ErrFinalizationBlocked
	}
	if _, err := tx.Exec(ctx, `INSERT INTO audit_events (event_type,metadata)
VALUES ('HIDDEN_ATTACHMENT_REMOVED',jsonb_build_object('text_links',$1::int,'dm_links',$2::int))`, textLinks.RowsAffected(), dmLinks.RowsAffected()); err != nil {
		return fmt.Errorf("audit hidden attachment removal: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit hidden attachment finalization: %w", err)
	}
	return nil
}
