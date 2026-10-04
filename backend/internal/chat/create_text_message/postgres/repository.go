package createtextmessagepostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
)

const selectCommittedMessage = `
SELECT id::text, channel_id::text, author_id::text, client_message_id::text,
       body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
FROM messages
WHERE author_id = $1 AND channel_id = $2 AND client_message_id = $3 AND kind = 'USER'`

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
