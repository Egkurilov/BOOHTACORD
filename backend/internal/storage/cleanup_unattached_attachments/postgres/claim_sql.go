package cleanupunattachedattachmentspostgres

func claimStatement(includeDM bool) string {
	guard := `AND NOT EXISTS (SELECT 1 FROM message_attachments AS link WHERE link.attachment_id = attachment.id)` + dmLinkGuard(includeDM)
	return `WITH turn AS (
    SELECT (nextval('attachments_unattached_cleanup_turn_seq') % 2)::int AS first_lane
), fresh AS (
    SELECT attachment.id, attachment.created_at
    FROM attachments AS attachment
    WHERE attachment.state = 'UNATTACHED' AND attachment.created_at < $1
      ` + guard + `
    ORDER BY attachment.created_at, attachment.id
    LIMIT $2
    FOR UPDATE OF attachment SKIP LOCKED
), retry AS (
    SELECT attachment.id, attachment.created_at, attachment.unattached_cleanup_retry_after
    FROM attachments AS attachment
    WHERE attachment.state = 'DELETING'
      AND (attachment.unattached_cleanup_retry_after IS NULL OR
           attachment.unattached_cleanup_retry_after <= clock_timestamp())
      ` + guard + `
    ORDER BY attachment.unattached_cleanup_retry_after NULLS FIRST, attachment.created_at, attachment.id
    LIMIT $2
    FOR UPDATE OF attachment SKIP LOCKED
), ranked AS (
    SELECT fresh.id, 0 AS lane,
           row_number() OVER (ORDER BY fresh.created_at, fresh.id) AS queue_position
    FROM fresh
    UNION ALL
    SELECT retry.id, 1 AS lane,
           row_number() OVER (ORDER BY retry.unattached_cleanup_retry_after NULLS FIRST,
                                       retry.created_at, retry.id) AS queue_position
    FROM retry
), selected AS (
    SELECT ranked.id
    FROM ranked CROSS JOIN turn
    ORDER BY ranked.queue_position,
             CASE WHEN ranked.lane = turn.first_lane THEN 0 ELSE 1 END
    LIMIT $2
), claimed AS (
    UPDATE attachments AS attachment
    SET state = 'DELETING',
        unattached_cleanup_attempts = LEAST(12, attachment.unattached_cleanup_attempts + 1),
        unattached_cleanup_retry_after = clock_timestamp() +
            make_interval(mins => 5 * LEAST(12, attachment.unattached_cleanup_attempts + 1))
    FROM selected
    WHERE attachment.id = selected.id
    RETURNING attachment.id::text, attachment.storage_key::text
)
SELECT id, storage_key FROM claimed`
}

func dmLinkGuard(includeDM bool) string {
	if !includeDM {
		return ""
	}
	return `
      AND NOT EXISTS (SELECT 1 FROM direct_message_attachments AS link WHERE link.attachment_id = attachment.id)`
}
