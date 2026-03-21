-- Add OAuth provider support to users table
ALTER TABLE users ADD COLUMN google_id VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN google_email VARCHAR(255);
ALTER TABLE users ADD COLUMN google_name VARCHAR(255);
ALTER TABLE users ADD COLUMN google_picture TEXT;

ALTER TABLE users ADD COLUMN apple_id VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN apple_email VARCHAR(255);
ALTER TABLE users ADD COLUMN apple_name VARCHAR(255);

-- Create indexes for OAuth lookups
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_id);
