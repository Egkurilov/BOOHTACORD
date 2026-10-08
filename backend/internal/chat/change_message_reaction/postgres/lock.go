package changemessagereactionpostgres

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	action "voice-platform/backend/internal/chat/change_message_reaction"
)

func lockTarget(ctx context.Context, tx pgx.Tx, in action.Input) ([]string, error) {
	var active bool
	err := tx.QueryRow(ctx, `SELECT true FROM users WHERE id=$1 AND blocked_at IS NULL FOR SHARE`, in.ActorID).Scan(&active)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, action.ErrUnavailable
	}
	if err != nil {
		return nil, err
	}
	if !in.Direct {
		err = tx.QueryRow(ctx, `SELECT true FROM messages m JOIN channels c ON c.id=m.channel_id JOIN users u ON u.id=$1 AND u.blocked_at IS NULL
 WHERE m.id=$2 AND c.id=$3 AND c.kind='TEXT' AND c.archived_at IS NULL AND m.deleted_at IS NULL
 FOR UPDATE OF m FOR SHARE OF c`, in.ActorID, in.MessageID, in.ConversationID).Scan(&active)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, action.ErrUnavailable
		}
		return nil, err
	}
	var first, second string
	err = tx.QueryRow(ctx, `SELECT dm.participant_one_id::text,dm.participant_two_id::text FROM direct_message_messages m
 JOIN direct_messages dm ON dm.id=m.direct_message_id WHERE m.id=$2 AND dm.id=$3 AND m.deleted_at IS NULL
 AND $1::uuid IN(dm.participant_one_id,dm.participant_two_id) FOR UPDATE OF m FOR SHARE OF dm`, in.ActorID, in.MessageID, in.ConversationID).Scan(&first, &second)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, action.ErrUnavailable
	}
	if err != nil {
		return nil, err
	}
	return []string{first, second}, nil
}
