CREATE TABLE IF NOT EXISTS direct_message_attachments (
    message_id UUID NOT NULL REFERENCES direct_message_messages(id) ON DELETE RESTRICT,
    attachment_id UUID NOT NULL UNIQUE REFERENCES attachments(id) ON DELETE RESTRICT,
    position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 9),
    PRIMARY KEY (message_id, attachment_id),
    CONSTRAINT direct_message_attachments_message_position_unique UNIQUE (message_id, position)
);
