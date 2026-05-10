ALTER TABLE users ADD COLUMN ai_credits_balance INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN ai_credits_last_refreshed_at TIMESTAMPTZ NULL;
