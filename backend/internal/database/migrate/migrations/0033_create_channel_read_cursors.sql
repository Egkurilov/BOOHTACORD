CREATE TABLE IF NOT EXISTS channel_read_cursors (
    account_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE RESTRICT,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE RESTRICT,
    message_created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, channel_id)
);
