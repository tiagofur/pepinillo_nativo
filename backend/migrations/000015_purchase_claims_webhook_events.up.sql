-- Purchase-token ownership (B1) and webhook event dedupe (B3).
-- A purchase token granted to one user can never be replayed for another:
-- the UNIQUE PRIMARY KEY makes the claim atomic under concurrency.
CREATE TABLE IF NOT EXISTS purchase_claims (
    platform       TEXT        NOT NULL,
    purchase_token TEXT        NOT NULL,
    user_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    claimed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (platform, purchase_token)
);
CREATE INDEX IF NOT EXISTS index_purchase_claims_user_id ON purchase_claims(user_id);

-- Processed webhook event IDs (RevenueCat may redeliver, out of order).
CREATE TABLE IF NOT EXISTS webhook_events (
    event_id    TEXT        NOT NULL PRIMARY KEY,
    source      TEXT        NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
