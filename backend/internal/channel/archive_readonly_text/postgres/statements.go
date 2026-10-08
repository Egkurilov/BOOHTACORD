package archivereadonlytextpostgres

const changeChannel = `WITH state AS (
 SELECT revision FROM channel_topology_state WHERE singleton=TRUE AND revision=$1
 AND EXISTS(SELECT 1 FROM users WHERE id=$3 AND role='ADMINISTRATOR' AND blocked_at IS NULL)
), changed AS (
 UPDATE channels SET archived_at=now(), readonly_archive=TRUE, updated_at=now()
 WHERE id=$2 AND kind='TEXT' AND archived_at IS NULL AND EXISTS(SELECT 1 FROM state) RETURNING id
), revised AS (
 UPDATE channel_topology_state SET revision=revision+1 WHERE singleton=TRUE AND revision=$1 AND EXISTS(SELECT 1 FROM changed) RETURNING revision
), welcome_cleared AS (
 UPDATE guild_settings SET welcome_channel_id=NULL,revision=revision+1,updated_at=now()
 WHERE singleton=TRUE AND welcome_channel_id IN(SELECT id FROM changed) RETURNING revision
), welcome_audited AS (
 INSERT INTO audit_events(actor_user_id,event_type,metadata)
 SELECT $3,'GUILD_WELCOME_SETTINGS_UPDATED',jsonb_build_object('revision',revision,'changed_fields',jsonb_build_array('welcome_channel_id'),'reason','readonly_archived') FROM welcome_cleared
), audited AS (
 INSERT INTO audit_events(actor_user_id,event_type,metadata)
 SELECT $3,'TEXT_CHANNEL_ARCHIVED_READONLY',jsonb_build_object('channel_id',id::text) FROM changed CROSS JOIN revised
) SELECT changed.id::text,revised.revision FROM changed CROSS JOIN revised`
