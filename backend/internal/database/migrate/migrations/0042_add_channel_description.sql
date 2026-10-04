ALTER TABLE channels ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '';

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'channels_description_length') THEN
        ALTER TABLE channels ADD CONSTRAINT channels_description_length CHECK (char_length(description) <= 200);
    END IF;
END $$;
