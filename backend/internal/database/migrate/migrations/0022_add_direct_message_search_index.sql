ALTER TABLE direct_message_messages
    ADD COLUMN IF NOT EXISTS search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', body)) STORED;

CREATE INDEX IF NOT EXISTS direct_message_messages_search_idx
    ON direct_message_messages USING GIN (search_vector)
    WHERE deleted_at IS NULL;
