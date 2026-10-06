-- Additive metadata only. Legacy workers/clients ignore these nullable columns.
ALTER TABLE voice_sfu_revocations ADD COLUMN IF NOT EXISTS trace_cause jsonb;
ALTER TABLE realtime_events ADD COLUMN IF NOT EXISTS trace_cause jsonb;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='voice_trace_cause_bounded' AND conrelid='voice_sfu_revocations'::regclass) THEN
  ALTER TABLE voice_sfu_revocations ADD CONSTRAINT voice_trace_cause_bounded CHECK (trace_cause IS NULL OR octet_length(trace_cause::text) <= 512);
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='event_trace_cause_bounded' AND conrelid='realtime_events'::regclass) THEN
  ALTER TABLE realtime_events ADD CONSTRAINT event_trace_cause_bounded CHECK (trace_cause IS NULL OR octet_length(trace_cause::text) <= 512);
 END IF;
END $$;

