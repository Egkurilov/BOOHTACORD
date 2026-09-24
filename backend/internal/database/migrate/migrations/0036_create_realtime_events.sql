CREATE TABLE IF NOT EXISTS realtime_events (
    sequence BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    id UUID PRIMARY KEY,
    boot_epoch UUID NOT NULL,
    kind TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    stored_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    payload JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    recipient_ids UUID[],
    CONSTRAINT realtime_events_recipients_nonempty CHECK (recipient_ids IS NULL OR cardinality(recipient_ids) > 0)
);

CREATE INDEX IF NOT EXISTS realtime_events_epoch_sequence_idx ON realtime_events (boot_epoch, sequence);
CREATE INDEX IF NOT EXISTS realtime_events_stored_at_idx ON realtime_events (stored_at, sequence);
