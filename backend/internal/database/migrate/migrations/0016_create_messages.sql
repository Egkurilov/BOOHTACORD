CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE RESTRICT,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    client_message_id UUID NOT NULL,
    body TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    reply_to_id UUID REFERENCES messages(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT messages_author_channel_client_message_unique UNIQUE (author_id, channel_id, client_message_id),
    CONSTRAINT messages_body_or_deleted_marker CHECK (
        (deleted_at IS NULL AND char_length(body) BETWEEN 1 AND 8000)
        OR (deleted_at IS NOT NULL AND body = '')
    )
);
