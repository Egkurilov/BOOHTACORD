CREATE TABLE IF NOT EXISTS voice_leases (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT CHECK (revocation_reason IN ('TRANSFER', 'KICK', 'CHANNEL_CLOSED', 'SESSION_REVOKED', 'BANNED', 'LOGOUT')),
    CHECK ((revoked_at IS NULL AND revocation_reason IS NULL) OR (revoked_at IS NOT NULL AND revocation_reason IS NOT NULL))
);
