package searchmessagespostgres

const searchMessages = `
WITH matching AS (
    SELECT 'CHANNEL'::text AS kind, m.id, m.channel_id, NULL::uuid AS direct_message_id,
           m.author_id, m.body, m.created_at, m.edited_at, m.revision, m.kind AS message_kind
    FROM messages m JOIN channels channel ON channel.id = m.channel_id
    WHERE channel.kind = 'TEXT' AND channel.archived_at IS NULL AND m.deleted_at IS NULL
      AND ($2::uuid IS NULL OR m.channel_id = $2::uuid) AND $3::uuid IS NULL
      AND ($5::uuid IS NULL OR m.author_id = $5::uuid)
      AND ($11::timestamptz IS NULL OR m.created_at >= $11::timestamptz)
      AND ($12::timestamptz IS NULL OR m.created_at < $12::timestamptz)
      AND ($6::boolean IS NULL OR (EXISTS (
          SELECT 1 FROM message_attachments link
          JOIN attachments attachment ON attachment.id = link.attachment_id
          WHERE link.message_id = m.id AND attachment.state = 'ATTACHED'
      )) = $6::boolean)
      AND m.search_vector @@ websearch_to_tsquery('simple', $4)
    UNION ALL
    SELECT 'DIRECT_MESSAGE'::text AS kind, dm_message.id, NULL::uuid AS channel_id, dm_message.direct_message_id,
           dm_message.author_id, dm_message.body, dm_message.created_at, dm_message.edited_at, dm_message.revision, 'USER'::text AS message_kind
    FROM direct_message_messages dm_message JOIN direct_messages dm ON dm.id = dm_message.direct_message_id
    WHERE dm_message.deleted_at IS NULL AND $2::uuid IS NULL
      AND ($3::uuid IS NULL OR dm.id = $3::uuid)
      AND $1::uuid IN (dm.participant_one_id, dm.participant_two_id)
      AND ($5::uuid IS NULL OR dm_message.author_id = $5::uuid)
      AND ($11::timestamptz IS NULL OR dm_message.created_at >= $11::timestamptz)
      AND ($12::timestamptz IS NULL OR dm_message.created_at < $12::timestamptz)
      AND ($6::boolean IS NULL OR (EXISTS (
          SELECT 1 FROM direct_message_attachments link
          JOIN attachments attachment ON attachment.id = link.attachment_id
          WHERE link.message_id = dm_message.id AND attachment.state = 'ATTACHED'
      )) = $6::boolean)
      AND dm_message.search_vector @@ websearch_to_tsquery('simple', $4)
)
SELECT kind, id::text, COALESCE(channel_id::text, ''), COALESCE(direct_message_id::text, ''),
       author_id::text, body, created_at, edited_at, revision, message_kind
FROM matching
WHERE $7::timestamptz IS NULL OR (created_at, id, kind) < ($7::timestamptz, $8::uuid, $9::text)
ORDER BY created_at DESC, id DESC, kind DESC
LIMIT $10`
