ALTER TABLE users
    DROP COLUMN IF EXISTS stripe_customer_id,
    DROP COLUMN IF EXISTS stripe_tier,
    DROP COLUMN IF EXISTS stripe_expires_at;
