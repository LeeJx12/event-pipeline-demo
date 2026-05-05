CREATE TABLE IF NOT EXISTS events_processed (
    id BIGSERIAL PRIMARY KEY,
    event_id TEXT NOT NULL UNIQUE,
    user_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    enrichment_found BOOLEAN NOT NULL DEFAULT false,
    enrichment_country TEXT,
    enrichment_tier TEXT,
    enrichment_signup_unix_ms BIGINT,
    enrichment_tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    enrichment_cache_hit BOOLEAN NOT NULL DEFAULT false,
    enrichment_available BOOLEAN NOT NULL DEFAULT false,
    kafka_partition INTEGER NOT NULL,
    kafka_offset BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_processed_user_id ON events_processed (user_id);
CREATE INDEX IF NOT EXISTS idx_events_processed_event_type ON events_processed (event_type);
CREATE INDEX IF NOT EXISTS idx_events_processed_processed_at ON events_processed (processed_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_processed_partition_offset ON events_processed (kafka_partition, kafka_offset);
