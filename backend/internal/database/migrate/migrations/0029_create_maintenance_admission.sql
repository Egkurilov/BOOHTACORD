CREATE TABLE IF NOT EXISTS maintenance_admission (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    active BOOLEAN NOT NULL DEFAULT FALSE,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO maintenance_admission (singleton, active)
VALUES (TRUE, FALSE)
ON CONFLICT (singleton) DO NOTHING;
