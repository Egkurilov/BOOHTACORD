ALTER TABLE channels ADD COLUMN IF NOT EXISTS readonly_archive BOOLEAN NOT NULL DEFAULT FALSE;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='channels_readonly_archive_state' AND conrelid='channels'::regclass) THEN
  ALTER TABLE channels ADD CONSTRAINT channels_readonly_archive_state CHECK(NOT readonly_archive OR (kind='TEXT' AND archived_at IS NOT NULL));
 END IF;
END $$;
