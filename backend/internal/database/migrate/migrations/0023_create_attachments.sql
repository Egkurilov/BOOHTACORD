CREATE TABLE IF NOT EXISTS attachments (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    channel_id UUID REFERENCES channels(id) ON DELETE RESTRICT,
    direct_message_id UUID REFERENCES direct_messages(id) ON DELETE RESTRICT,
    original_name TEXT NOT NULL CHECK (char_length(original_name) > 0),
    storage_key UUID NOT NULL UNIQUE,
    byte_size BIGINT NOT NULL CHECK (byte_size BETWEEN 0 AND 25000000),
    state TEXT NOT NULL CHECK (state IN ('UNATTACHED', 'ATTACHED', 'HIDDEN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    attached_at TIMESTAMPTZ,
    hidden_at TIMESTAMPTZ,
    CONSTRAINT attachments_exactly_one_target CHECK (
        (channel_id IS NOT NULL AND direct_message_id IS NULL) OR
        (channel_id IS NULL AND direct_message_id IS NOT NULL)
    ),
    CONSTRAINT attachments_state_timestamps CHECK (
        (state = 'UNATTACHED' AND attached_at IS NULL AND hidden_at IS NULL) OR
        (state = 'ATTACHED' AND attached_at IS NOT NULL AND hidden_at IS NULL) OR
        (state = 'HIDDEN' AND attached_at IS NOT NULL AND hidden_at IS NOT NULL)
    )
);
