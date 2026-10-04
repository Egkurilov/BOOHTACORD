CREATE TABLE IF NOT EXISTS guild_settings (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80 AND name !~ '[[:cntrl:]]'),
    revision BIGINT NOT NULL DEFAULT 1 CHECK (revision > 0),
    welcome_channel_id UUID REFERENCES channels(id) ON DELETE RESTRICT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO guild_settings (singleton, name) VALUES (TRUE, 'Моя гильдия')
    ON CONFLICT (singleton) DO NOTHING;
