package listmessagereactionspostgres

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	list "voice-platform/backend/internal/chat/list_message_reactions"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool} }
func (r Repository) List(ctx context.Context, in list.Input) ([]list.Reaction, error) {
	available := false
	probe := `SELECT EXISTS(SELECT 1 FROM users u JOIN channels c ON c.id=$2 WHERE u.id=$1 AND u.blocked_at IS NULL AND c.kind='TEXT' AND c.archived_at IS NULL)`
	query := `SELECT m.id::text,reaction.emoji,count(*)::integer,bool_or(reaction.account_id=$1) FROM messages m
 JOIN channels c ON c.id=m.channel_id JOIN text_message_reactions reaction ON reaction.message_id=m.id
 JOIN users u ON u.id=$1 AND u.blocked_at IS NULL WHERE c.id=$2 AND c.kind='TEXT' AND c.archived_at IS NULL
 AND m.deleted_at IS NULL AND m.id=ANY($3::uuid[]) GROUP BY m.id,reaction.emoji ORDER BY m.id,reaction.emoji LIMIT 600`
	if in.Direct {
		probe = `SELECT EXISTS(SELECT 1 FROM users u JOIN direct_messages dm ON dm.id=$2 WHERE u.id=$1 AND u.blocked_at IS NULL AND $1::uuid IN(dm.participant_one_id,dm.participant_two_id))`
		query = `SELECT m.id::text,reaction.emoji,count(*)::integer,bool_or(reaction.account_id=$1) FROM direct_message_messages m
 JOIN direct_messages dm ON dm.id=m.direct_message_id JOIN direct_message_reactions reaction ON reaction.message_id=m.id
 JOIN users u ON u.id=$1 AND u.blocked_at IS NULL WHERE dm.id=$2 AND $1::uuid IN(dm.participant_one_id,dm.participant_two_id)
 AND m.deleted_at IS NULL AND m.id=ANY($3::uuid[]) GROUP BY m.id,reaction.emoji ORDER BY m.id,reaction.emoji LIMIT 600`
	}
	if err := r.pool.QueryRow(ctx, probe, in.ActorID, in.ConversationID).Scan(&available); err != nil {
		return nil, err
	}
	if !available {
		return nil, list.ErrUnavailable
	}
	rows, err := r.pool.Query(ctx, query, in.ActorID, in.ConversationID, in.MessageIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []list.Reaction{}
	for rows.Next() {
		var item list.Reaction
		if err = rows.Scan(&item.MessageID, &item.Emoji, &item.Count, &item.Mine); err != nil {
			return nil, err
		}
		result = append(result, item)
	}
	return result, rows.Err()
}
