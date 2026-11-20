-- #953: bind the RevenueCat app_user_id of a NATIVE purchase to the account,
-- so webhook events carrying a non-UUID RC ID resolve to the buyer and the
-- claim endpoint stays idempotent. Unique allows many NULLs (most users).
ALTER TABLE users ADD COLUMN IF NOT EXISTS rc_app_user_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_rc_app_user_id ON users (rc_app_user_id)
    WHERE rc_app_user_id IS NOT NULL;
