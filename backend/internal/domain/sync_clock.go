package domain

import "time"

// ResolveSyncTimestamp normalizes a device-stamped updatedAt for last-write-wins.
//
// Sync code used to compare device time but store server receipt time: after
// one round trip the stored stamp was always ~now, so a device with a slow
// clock had ALL later edits rejected against its own earlier writes
// (systematic self-lockout). Storing the client stamp preserves
// self-ordering under any skew. The future side is clamped to receipt time
// so a fast device cannot poison the row with a future stamp that beats
// every later legitimate write. Zero stamps (legacy callers) default to now.
func ResolveSyncTimestamp(clientUpdatedAt, now time.Time) time.Time {
	if clientUpdatedAt.IsZero() {
		return now
	}
	if clientUpdatedAt.After(now) {
		return now
	}
	return clientUpdatedAt
}
