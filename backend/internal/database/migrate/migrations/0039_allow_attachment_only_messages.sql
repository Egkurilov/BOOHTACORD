ALTER TABLE messages
    DROP CONSTRAINT IF EXISTS messages_body_or_deleted_marker;

ALTER TABLE messages
    ADD CONSTRAINT messages_body_or_deleted_marker CHECK (
        (deleted_at IS NULL AND char_length(body) BETWEEN 0 AND 8000)
        OR (deleted_at IS NOT NULL AND body = '')
    );

ALTER TABLE direct_message_messages
    DROP CONSTRAINT IF EXISTS direct_message_messages_body_or_deleted_marker;

ALTER TABLE direct_message_messages
    ADD CONSTRAINT direct_message_messages_body_or_deleted_marker CHECK (
        (deleted_at IS NULL AND char_length(body) BETWEEN 0 AND 8000)
        OR (deleted_at IS NOT NULL AND body = '')
    );
