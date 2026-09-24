ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS mention_user_ids UUID[] NOT NULL DEFAULT '{}'::uuid[];

ALTER TABLE direct_message_messages
    ADD COLUMN IF NOT EXISTS mention_user_ids UUID[] NOT NULL DEFAULT '{}'::uuid[];

CREATE INDEX IF NOT EXISTS messages_live_mentions_idx
    ON messages USING GIN (mention_user_ids) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS direct_message_messages_live_mentions_idx
    ON direct_message_messages USING GIN (mention_user_ids) WHERE deleted_at IS NULL;
