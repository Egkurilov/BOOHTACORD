ALTER TABLE direct_message_messages
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES direct_message_messages(id) ON DELETE RESTRICT;
