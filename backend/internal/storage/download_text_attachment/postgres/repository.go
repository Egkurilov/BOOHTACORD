package downloadtextattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	downloadtextattachment "voice-platform/backend/internal/storage/download_text_attachment"
)

const findAttachment = `
SELECT attachments.original_name, attachments.storage_key::text, attachments.byte_size
FROM users
JOIN channels ON channels.id = $2
JOIN attachments ON attachments.id = $3 AND attachments.channel_id = channels.id
JOIN message_attachments ON message_attachments.attachment_id = attachments.id
JOIN messages ON messages.id = message_attachments.message_id AND messages.channel_id = channels.id
WHERE users.id = $1
  AND users.blocked_at IS NULL
  AND channels.kind = 'TEXT'
  AND ((NOT $4::boolean AND channels.archived_at IS NULL)
       OR ($4::boolean AND channels.archived_at IS NOT NULL AND channels.readonly_archive))
  AND attachments.state = 'ATTACHED'
  AND messages.deleted_at IS NULL`

type Row interface{ Scan(...any) error }

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Find(ctx context.Context, input downloadtextattachment.Input) (downloadtextattachment.Metadata, error) {
	var metadata downloadtextattachment.Metadata
	err := repository.database.QueryRow(ctx, findAttachment, input.ActorID, input.ChannelID, input.AttachmentID, input.ReadArchive).Scan(
		&metadata.OriginalName, &metadata.StorageKey, &metadata.SizeBytes,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return downloadtextattachment.Metadata{}, downloadtextattachment.ErrAttachmentUnavailable
	}
	if err != nil {
		return downloadtextattachment.Metadata{}, fmt.Errorf("find downloadable text attachment metadata: %w", err)
	}
	return metadata, nil
}
