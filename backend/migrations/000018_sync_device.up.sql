-- #942 S5: device-bound server backup for Free and Pepinillo+ tiers.
-- NULL (or empty) means "not bound yet" — the first successful sync
-- upload claims the binding. Everywhere+ tiers bypass the check and stay
-- multi-device.
ALTER TABLE users ADD COLUMN sync_device_id TEXT NULL;
