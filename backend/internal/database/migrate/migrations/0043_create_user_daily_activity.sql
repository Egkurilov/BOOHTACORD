CREATE TABLE IF NOT EXISTS user_daily_activity (
    activity_day DATE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (activity_day, user_id)
);

CREATE TABLE IF NOT EXISTS user_activity_collection (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO user_activity_collection(singleton) VALUES (TRUE) ON CONFLICT DO NOTHING;
