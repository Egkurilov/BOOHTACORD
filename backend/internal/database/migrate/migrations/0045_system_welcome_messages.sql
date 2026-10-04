ALTER TABLE messages ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'USER'
    CHECK (kind IN ('USER', 'SYSTEM_WELCOME'));
DO $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='messages'::regclass AND conname='welcome_shape') THEN
ALTER TABLE messages ADD CONSTRAINT welcome_shape CHECK (
    kind <> 'SYSTEM_WELCOME' OR (
        reply_to_id IS NULL AND edited_at IS NULL AND mention_user_ids = ARRAY[author_id]
    )
);
END IF;
END;
$$;
CREATE UNIQUE INDEX IF NOT EXISTS messages_one_welcome_per_account
    ON messages(author_id) WHERE kind = 'SYSTEM_WELCOME';

-- Enforce shape at the persistence boundary, including accidental future writers.
CREATE OR REPLACE FUNCTION guard_system_welcome() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF OLD.kind <> NEW.kind THEN
            RAISE EXCEPTION 'message kind is immutable' USING ERRCODE = '23514';
        END IF;
        IF OLD.kind = 'SYSTEM_WELCOME' AND (
            NEW.author_id <> OLD.author_id OR NEW.channel_id <> OLD.channel_id
            OR NEW.client_message_id <> OLD.client_message_id
            OR NEW.created_at <> OLD.created_at
            OR (NEW.body <> OLD.body AND NEW.deleted_at IS NULL)
        ) THEN
            RAISE EXCEPTION 'system welcome is immutable' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF NEW.reply_to_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM messages WHERE id=NEW.reply_to_id AND kind='SYSTEM_WELCOME'
    ) THEN
        RAISE EXCEPTION 'cannot reply to system welcome' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS messages_system_welcome_guard ON messages;
CREATE TRIGGER messages_system_welcome_guard BEFORE INSERT OR UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION guard_system_welcome();

CREATE OR REPLACE FUNCTION guard_welcome_attachment() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM messages WHERE id=NEW.message_id AND kind='SYSTEM_WELCOME') THEN
        RAISE EXCEPTION 'system welcome cannot have attachments' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS message_attachments_welcome_guard ON message_attachments;
CREATE TRIGGER message_attachments_welcome_guard BEFORE INSERT OR UPDATE ON message_attachments
    FOR EACH ROW EXECUTE FUNCTION guard_welcome_attachment();
