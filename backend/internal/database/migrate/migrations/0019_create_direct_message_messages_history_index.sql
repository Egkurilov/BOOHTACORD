CREATE INDEX IF NOT EXISTS direct_message_messages_history_idx
    ON direct_message_messages (direct_message_id, created_at DESC, id DESC);
