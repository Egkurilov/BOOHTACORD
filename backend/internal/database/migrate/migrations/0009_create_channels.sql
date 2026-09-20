CREATE TABLE IF NOT EXISTS channels (
    id UUID PRIMARY KEY,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
    kind TEXT NOT NULL CHECK (kind IN ('TEXT', 'VOICE')),
    position INTEGER NOT NULL CHECK (position >= 0),
    archived_at TIMESTAMPTZ,
    admission_closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT channels_category_position_unique UNIQUE (category_id, position) DEFERRABLE INITIALLY IMMEDIATE
);
