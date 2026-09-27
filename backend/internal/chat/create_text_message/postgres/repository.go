package createtextmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

const insertMessage = `
WITH existing_message AS (
    SELECT id::text, channel_id::text, author_id::text, client_message_id::text,
           body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
    FROM messages
    WHERE author_id = $3 AND channel_id = $2 AND client_message_id = $4
), channel AS (
    SELECT id FROM channels WHERE id = $2 AND kind = 'TEXT' AND archived_at IS NULL
), reply AS (
    SELECT id FROM messages WHERE id = $6 AND channel_id = $2
), requested_attachments AS (
    SELECT attachment_id, position - 1 AS position
    FROM unnest($7::uuid[]) WITH ORDINALITY AS requested(attachment_id, position)
), valid_attachments AS (
    SELECT requested.attachment_id, requested.position
    FROM requested_attachments AS requested
    JOIN attachments AS attachment ON attachment.id = requested.attachment_id
    JOIN channel ON true
    WHERE attachment.owner_id = $3
      AND attachment.channel_id = channel.id
      AND attachment.state = 'UNATTACHED'
    FOR UPDATE OF attachment
), attachments_valid AS (
    SELECT (SELECT count(*) FROM requested_attachments) = (SELECT count(*) FROM valid_attachments) AS value
), valid_mentions AS (
    SELECT account.id FROM users AS account
    WHERE account.id = ANY($8::uuid[]) AND account.blocked_at IS NULL AND account.id <> $3
    FOR SHARE OF account
), inserted AS (
    INSERT INTO messages (id, channel_id, author_id, client_message_id, body, reply_to_id, mention_user_ids)
    SELECT $1, channel.id, $3, $4, $5, reply.id, $8::uuid[]
    FROM channel LEFT JOIN reply ON $6::uuid IS NOT NULL
    WHERE NOT EXISTS (SELECT 1 FROM existing_message)
      AND ($5 <> '' OR cardinality($7::uuid[]) > 0)
      AND ($6::uuid IS NULL OR reply.id IS NOT NULL)
      AND (SELECT value FROM attachments_valid)
      AND (SELECT count(*) FROM valid_mentions) = cardinality($8::uuid[])
    RETURNING id::text, channel_id::text, author_id::text, client_message_id::text, body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
), linked AS (
    INSERT INTO message_attachments (message_id, attachment_id, position)
    SELECT inserted.id::uuid, valid_attachments.attachment_id, valid_attachments.position
    FROM inserted CROSS JOIN valid_attachments
    RETURNING attachment_id
), updated AS (
    UPDATE attachments AS attachment
    SET state = 'ATTACHED', attached_at = now()
    FROM linked
    WHERE attachment.id = linked.attachment_id
    RETURNING attachment.id
)
SELECT * FROM existing_message
UNION ALL
SELECT * FROM inserted
WHERE (SELECT count(*) FROM updated) = (SELECT count(*) FROM valid_attachments)`

const selectCommittedMessage = `
SELECT id::text, channel_id::text, author_id::text, client_message_id::text,
       body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
FROM messages
WHERE author_id = $1 AND channel_id = $2 AND client_message_id = $3`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) Create(context context.Context, request createtextmessage.Request) (createtextmessage.Result, error) {
	var result createtextmessage.Result
	var replyID any
	if request.ReplyToID != "" {
		replyID = request.ReplyToID
	}
	mentions := append([]string{}, request.MentionUserIDs...)
	err := repository.database.QueryRow(context, insertMessage, request.ID, request.ChannelID, request.ActorID, request.ClientMessageID, request.Body, replyID, request.AttachmentIDs, mentions).Scan(
		&result.ID, &result.ChannelID, &result.AuthorID, &result.ClientMessageID, &result.Body, &result.ReplyToID, &result.Revision, &result.CreatedAt, &result.MentionUserIDs,
	)
	var postgresError *pgconn.PgError
	idempotencyConflict := errors.As(err, &postgresError) && postgresError.Code == "23505" && postgresError.ConstraintName == "messages_author_channel_client_message_unique"
	if errors.Is(err, pgx.ErrNoRows) || idempotencyConflict {
		var committed createtextmessage.Result
		lookupErr := repository.database.QueryRow(context, selectCommittedMessage, request.ActorID, request.ChannelID, request.ClientMessageID).Scan(
			&committed.ID, &committed.ChannelID, &committed.AuthorID, &committed.ClientMessageID, &committed.Body, &committed.ReplyToID, &committed.Revision, &committed.CreatedAt, &committed.MentionUserIDs,
		)
		if lookupErr == nil {
			return committed, nil
		}
		if lookupErr != nil && !errors.Is(lookupErr, pgx.ErrNoRows) {
			return createtextmessage.Result{}, fmt.Errorf("read committed text message: %w", errors.Join(err, lookupErr))
		}
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return createtextmessage.Result{}, createtextmessage.ErrChannelUnavailable
	}
	if err != nil {
		return createtextmessage.Result{}, fmt.Errorf("insert text message: %w", err)
	}
	return result, nil
}
