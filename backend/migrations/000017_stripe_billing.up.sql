-- Stripe billing state (web purchases). Kept separate from the
-- RevenueCat/StoreKit/Play columns so the effective tier resolves as the
-- maximum across providers (see domain.User.EffectiveTierAt).
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS stripe_customer_id     TEXT,
    ADD COLUMN IF NOT EXISTS stripe_tier            TEXT,
    ADD COLUMN IF NOT EXISTS stripe_expires_at      TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS index_users_stripe_customer_id ON users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
