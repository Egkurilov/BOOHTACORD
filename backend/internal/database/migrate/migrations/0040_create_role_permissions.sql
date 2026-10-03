CREATE TABLE IF NOT EXISTS role_permissions (
    role TEXT PRIMARY KEY CHECK (role = 'MEMBER'),
    text_create BOOLEAN NOT NULL,
    text_delete BOOLEAN NOT NULL,
    voice_create BOOLEAN NOT NULL,
    voice_delete BOOLEAN NOT NULL,
    category_create BOOLEAN NOT NULL,
    category_delete BOOLEAN NOT NULL,
    revision BIGINT NOT NULL CHECK (revision > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id)
);

INSERT INTO role_permissions (
    role, text_create, text_delete, voice_create, voice_delete,
    category_create, category_delete, revision
) VALUES ('MEMBER', TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, 1)
ON CONFLICT (role) DO NOTHING;
