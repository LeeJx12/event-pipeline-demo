CREATE TABLE IF NOT EXISTS user_metadata (
    user_id TEXT PRIMARY KEY,
    country TEXT NOT NULL,
    tier TEXT NOT NULL,
    signup_unix_ms BIGINT NOT NULL,
    tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_metadata_tier ON user_metadata (tier);
