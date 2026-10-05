package inspectattachmentcleanup

const reportSQL = `WITH facts AS (
 SELECT a.*,
 EXISTS (SELECT 1 FROM message_attachments l WHERE l.attachment_id=a.id)
 OR EXISTS (SELECT 1 FROM direct_message_attachments l WHERE l.attachment_id=a.id) AS linked,
 EXISTS (SELECT 1 FROM message_attachments l JOIN messages m ON m.id=l.message_id WHERE l.attachment_id=a.id AND m.deleted_at IS NULL)
 OR EXISTS (SELECT 1 FROM direct_message_attachments l JOIN direct_message_messages m ON m.id=l.message_id WHERE l.attachment_id=a.id AND m.deleted_at IS NULL) AS live
 FROM attachments a
 WHERE ($1='UNATTACHED' AND state IN ('UNATTACHED','DELETING')) OR ($1='HIDDEN' AND state IN ('HIDDEN','ATTACHED'))
), classified AS (
 SELECT *, CASE
 WHEN $1='UNATTACHED' AND linked THEN 'linked'
 WHEN $1='HIDDEN' AND live THEN 'live_link'
 WHEN $1='HIDDEN' AND state='ATTACHED' AND NOT linked THEN 'published'
 WHEN state='UNATTACHED' AND created_at >= $2::timestamptz-interval '24 hours' THEN 'fresh'
 WHEN state='DELETING' AND unattached_cleanup_retry_after > $2::timestamptz THEN 'retry_deferred'
 WHEN $1='HIDDEN' AND hidden_cleanup_claim_token IS NOT NULL AND hidden_cleanup_claimed_at >= $2::timestamptz-interval '5 minutes' THEN 'claim_active'
 ELSE 'eligible' END AS reason,
 CASE WHEN state='DELETING' THEN COALESCE(unattached_cleanup_retry_after,created_at)
 WHEN hidden_cleanup_claim_token IS NOT NULL THEN hidden_cleanup_claimed_at END AS retry_since
 FROM facts
)
SELECT reason, count(*)::bigint, sum(byte_size)::bigint,
 COALESCE(max(GREATEST(extract(epoch from ($2::timestamptz-retry_since)),0)),0)::double precision
FROM classified GROUP BY reason`
