ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (to_tsvector('simple', body)) STORED;

CREATE INDEX IF NOT EXISTS messages_search_idx
    ON messages USING GIN (search_vector)
    WHERE deleted_at IS NULL;
