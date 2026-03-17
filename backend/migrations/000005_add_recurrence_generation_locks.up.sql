CREATE TABLE IF NOT EXISTS recurrence_generation_locks (
    lock_key TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recurrence_generation_locks_expires_at
    ON recurrence_generation_locks (expires_at);

