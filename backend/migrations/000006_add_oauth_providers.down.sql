-- Rollback OAuth provider fields
DROP INDEX IF EXISTS idx_users_google_id;
DROP INDEX IF EXISTS idx_users_apple_id;

ALTER TABLE users DROP COLUMN google_picture;
ALTER TABLE users DROP COLUMN google_name;
ALTER TABLE users DROP COLUMN google_email;
ALTER TABLE users DROP COLUMN google_id;

ALTER TABLE users DROP COLUMN apple_name;
ALTER TABLE users DROP COLUMN apple_email;
ALTER TABLE users DROP COLUMN apple_id;
