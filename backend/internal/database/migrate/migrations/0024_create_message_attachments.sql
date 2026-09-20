CREATE TABLE IF NOT EXISTS message_attachments (
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE RESTRICT,
    attachment_id UUID NOT NULL UNIQUE REFERENCES attachments(id) ON DELETE RESTRICT,
    position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 9),
    PRIMARY KEY (message_id, attachment_id),
    CONSTRAINT message_attachments_message_position_unique UNIQUE (message_id, position)
);
