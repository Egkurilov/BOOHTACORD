CREATE TABLE IF NOT EXISTS voice_timeouts (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    reason_code TEXT NOT NULL CHECK(reason_code IN ('DISRUPTION','HARASSMENT','SPAM','OTHER')),
    updated_by UUID NOT NULL REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Also fail closed for legacy API images which do not query voice_timeouts.
CREATE OR REPLACE FUNCTION enforce_voice_timeout_on_lease() RETURNS trigger AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.user_id::text, 0));
    IF EXISTS (SELECT 1 FROM voice_timeouts
               WHERE user_id=NEW.user_id AND expires_at > clock_timestamp()) THEN
        RAISE EXCEPTION 'voice admission restricted' USING ERRCODE='42501';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS voice_timeout_lease_guard ON voice_leases;
CREATE TRIGGER voice_timeout_lease_guard BEFORE INSERT ON voice_leases
    FOR EACH ROW EXECUTE FUNCTION enforce_voice_timeout_on_lease();
