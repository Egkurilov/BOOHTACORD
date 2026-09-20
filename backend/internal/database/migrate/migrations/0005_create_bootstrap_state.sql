CREATE TABLE IF NOT EXISTS bootstrap_state (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    administrator_id UUID UNIQUE REFERENCES users(id),
    initialized_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
