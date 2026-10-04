package createtextmessagepostgres

const insertMessage = `
WITH existing_message AS (
    SELECT id::text, channel_id::text, author_id::text, client_message_id::text,
           body, COALESCE(reply_to_id::text, ''), revision, created_at, mention_user_ids::text[]
    FROM messages
    WHERE author_id = $3 AND channel_id = $2 AND client_message_id = $4 AND kind = 'USER'
), channel AS (
    SELECT id FROM channels WHERE id = $2 AND kind = 'TEXT' AND archived_at IS NULL
), reply AS (
    SELECT id FROM messages WHERE id = $6 AND channel_id = $2 AND kind = 'USER'
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
