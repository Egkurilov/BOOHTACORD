CREATE TABLE IF NOT EXISTS direct_message_messages (
    id UUID PRIMARY KEY,
    direct_message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE RESTRICT,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    client_message_id UUID NOT NULL,
    body TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT direct_message_messages_author_client_unique UNIQUE (author_id, direct_message_id, client_message_id),
    CONSTRAINT direct_message_messages_body_or_deleted_marker CHECK (
        (deleted_at IS NULL AND char_length(body) BETWEEN 1 AND 8000)
        OR (deleted_at IS NOT NULL AND body = '')
    )
);
