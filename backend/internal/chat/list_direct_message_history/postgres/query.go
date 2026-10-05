package listdirectmessagehistorypostgres

import "strings"

const selectReadableDirectMessage = `
SELECT EXISTS(
    SELECT 1 FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
)`

const selectDirectMessageHistory = `
WITH readable_pair AS (
    SELECT dm.id FROM direct_messages dm
    WHERE dm.id = $1
      AND $2::uuid IN (dm.participant_one_id, dm.participant_two_id)
), cursor AS (
    SELECT created_at, id FROM direct_message_messages
    WHERE id = $3::uuid AND direct_message_id = (SELECT id FROM readable_pair)
)
SELECT m.id::text, m.direct_message_id::text, m.author_id::text, m.client_message_id::text,
       CASE WHEN m.deleted_at IS NULL THEN m.body ELSE '' END, COALESCE(m.reply_to_id::text, ''), m.created_at, m.edited_at, m.revision, m.deleted_at IS NOT NULL,
       CASE WHEN m.deleted_at IS NULL THEN m.mention_user_ids::text[] ELSE ARRAY[]::text[] END,
       COALESCE(reply.id::text, ''), COALESCE(reply.author_id::text, ''), CASE WHEN reply.deleted_at IS NULL THEN COALESCE(reply.body, '') ELSE '' END, reply.deleted_at IS NOT NULL,
       COALESCE((
           SELECT jsonb_agg(jsonb_build_object('id', a.id::text, 'original_name', a.original_name, 'byte_size', a.byte_size) ORDER BY link.position)
           FROM direct_message_attachments link
           JOIN attachments a ON a.id = link.attachment_id
           WHERE link.message_id = m.id AND a.state = 'ATTACHED' AND m.deleted_at IS NULL
       ), '[]'::jsonb)
FROM direct_message_messages m
LEFT JOIN direct_message_messages reply
  ON reply.id = m.reply_to_id
 AND reply.direct_message_id = m.direct_message_id
WHERE m.direct_message_id = (SELECT id FROM readable_pair)
  AND ($3::uuid IS NULL OR (m.created_at, m.id) < (SELECT created_at, id FROM cursor)
       OR ($5::bool AND m.id = $3::uuid))
ORDER BY m.created_at DESC, m.id DESC
LIMIT $4`

func historyQuery(after bool) string {
	if !after {
		return selectDirectMessageHistory
	}
	query := strings.Replace(selectDirectMessageHistory, "(m.created_at, m.id) <", "(m.created_at, m.id) >", 1)
	return strings.Replace(query, "ORDER BY m.created_at DESC, m.id DESC", "ORDER BY m.created_at ASC, m.id ASC", 1)
}
