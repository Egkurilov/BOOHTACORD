package listmymentionspostgres

const selectMentions = `
WITH matching AS (
    SELECT 'CHANNEL'::text AS kind, message.id, message.channel_id AS conversation_id, message.author_id, message.created_at
    FROM messages message JOIN channels channel ON channel.id = message.channel_id
    WHERE channel.kind = 'TEXT' AND channel.archived_at IS NULL AND message.deleted_at IS NULL
      AND $1::uuid = ANY(message.mention_user_ids)
    UNION ALL
    SELECT 'DIRECT_MESSAGE'::text AS kind, message.id, message.direct_message_id AS conversation_id, message.author_id, message.created_at
    FROM direct_message_messages message JOIN direct_messages pair ON pair.id = message.direct_message_id
    WHERE message.deleted_at IS NULL AND $1::uuid = ANY(message.mention_user_ids)
      AND $1::uuid IN (pair.participant_one_id, pair.participant_two_id)
)
SELECT kind, id::text, conversation_id::text, author_id::text, created_at
FROM matching
WHERE $2::timestamptz IS NULL OR (created_at, id, kind) < ($2::timestamptz, $3::uuid, $4::text)
ORDER BY created_at DESC, id DESC, kind DESC
LIMIT $5`
