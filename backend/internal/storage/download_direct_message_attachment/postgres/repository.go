package downloaddirectmessageattachmentpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	download "voice-platform/backend/internal/storage/download_direct_message_attachment"
)

const findAttachment = `
SELECT attachment.original_name, attachment.storage_key::text, attachment.byte_size
FROM direct_messages dm
JOIN users actor ON actor.id = $1 AND actor.blocked_at IS NULL
JOIN direct_message_attachments link ON link.attachment_id = $3
JOIN direct_message_messages message ON message.id = link.message_id
    AND message.direct_message_id = dm.id AND message.deleted_at IS NULL
JOIN attachments attachment ON attachment.id = link.attachment_id
    AND attachment.direct_message_id = dm.id AND attachment.state = 'ATTACHED'
WHERE dm.id = $2
  AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Find(ctx context.Context, input download.Input) (download.Metadata, error) {
	var metadata download.Metadata
	err := repository.database.QueryRow(ctx, findAttachment, input.ActorID, input.DirectMessageID, input.AttachmentID).Scan(
		&metadata.OriginalName, &metadata.StorageKey, &metadata.SizeBytes,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return download.Metadata{}, download.ErrAttachmentUnavailable
	}
	if err != nil {
		return download.Metadata{}, fmt.Errorf("select direct message attachment metadata: %w", err)
	}
	return metadata, nil
}
