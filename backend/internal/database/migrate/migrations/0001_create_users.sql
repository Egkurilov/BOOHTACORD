CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    login TEXT NOT NULL UNIQUE CHECK (login ~ '^[a-z0-9_.-]{3,32}$'),
    display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 64),
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('MEMBER', 'ADMINISTRATOR')),
    blocked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
