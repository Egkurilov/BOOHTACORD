CREATE TABLE IF NOT EXISTS text_message_reactions (
 message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
 account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 emoji TEXT NOT NULL CHECK(emoji IN('👍','❤️','😂','🎉','👀','✅')),
 PRIMARY KEY(message_id,account_id,emoji)
);
CREATE TABLE IF NOT EXISTS direct_message_reactions (
 message_id UUID NOT NULL REFERENCES direct_message_messages(id) ON DELETE CASCADE,
 account_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 emoji TEXT NOT NULL CHECK(emoji IN('👍','❤️','😂','🎉','👀','✅')),
 PRIMARY KEY(message_id,account_id,emoji)
);
CREATE TABLE IF NOT EXISTS text_message_pins (
 message_id UUID PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
 pinned_by UUID REFERENCES users(id) ON DELETE SET NULL,
 pinned_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS text_message_pins_order ON text_message_pins(pinned_at DESC,message_id DESC);
CREATE OR REPLACE FUNCTION clear_text_message_social() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
 DELETE FROM text_message_reactions WHERE message_id=NEW.id;
 DELETE FROM text_message_pins WHERE message_id=NEW.id;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS text_message_social_deleted ON messages;
CREATE TRIGGER text_message_social_deleted AFTER UPDATE OF deleted_at ON messages
 FOR EACH ROW WHEN(OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL) EXECUTE FUNCTION clear_text_message_social();
CREATE OR REPLACE FUNCTION clear_direct_message_social() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
 DELETE FROM direct_message_reactions WHERE message_id=NEW.id;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS direct_message_social_deleted ON direct_message_messages;
CREATE TRIGGER direct_message_social_deleted AFTER UPDATE OF deleted_at ON direct_message_messages
 FOR EACH ROW WHEN(OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL) EXECUTE FUNCTION clear_direct_message_social();
