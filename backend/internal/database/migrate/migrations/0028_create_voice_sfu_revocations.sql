CREATE TABLE IF NOT EXISTS voice_sfu_revocations (
    lease_id UUID PRIMARY KEY REFERENCES voice_leases(id) ON DELETE RESTRICT,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE RESTRICT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    claim_token UUID,
    claimed_at TIMESTAMPTZ,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_error_code TEXT,
    CHECK ((completed_at IS NULL) OR (last_error_code IS NULL)),
    CHECK ((claim_token IS NULL) = (claimed_at IS NULL))
);
