CREATE TABLE IF NOT EXISTS direct_message_read_cursors (
    account_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    direct_message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE RESTRICT,
    message_id UUID NOT NULL REFERENCES direct_message_messages(id) ON DELETE RESTRICT,
    message_created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, direct_message_id)
);
