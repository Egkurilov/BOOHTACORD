package restorereadonlytextpostgres

const changeChannel = `WITH state AS (
 SELECT revision FROM channel_topology_state WHERE singleton=TRUE AND revision=$1
 AND EXISTS(SELECT 1 FROM users WHERE id=$3 AND role='ADMINISTRATOR' AND blocked_at IS NULL)
), changed AS (
 UPDATE channels SET archived_at=NULL, readonly_archive=FALSE, updated_at=now()
 WHERE id=$2 AND kind='TEXT' AND archived_at IS NOT NULL AND readonly_archive AND EXISTS(SELECT 1 FROM state) RETURNING id
), revised AS (
 UPDATE channel_topology_state SET revision=revision+1 WHERE singleton=TRUE AND revision=$1 AND EXISTS(SELECT 1 FROM changed) RETURNING revision
), audited AS (
 INSERT INTO audit_events(actor_user_id,event_type,metadata)
 SELECT $3,'TEXT_CHANNEL_RESTORED',jsonb_build_object('channel_id',id::text) FROM changed CROSS JOIN revised
) SELECT changed.id::text,revised.revision FROM changed CROSS JOIN revised`
