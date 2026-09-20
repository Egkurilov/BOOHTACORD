CREATE TABLE IF NOT EXISTS direct_messages (
    id UUID PRIMARY KEY,
    participant_one_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    participant_two_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT direct_messages_distinct_participants CHECK (participant_one_id < participant_two_id),
    CONSTRAINT direct_messages_unique_pair UNIQUE (participant_one_id, participant_two_id)
);
