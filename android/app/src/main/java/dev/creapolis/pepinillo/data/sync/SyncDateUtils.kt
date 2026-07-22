package dev.creapolis.pepinillo.data.sync

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

object SyncDateUtils {

    fun Long.toRfc3339(): String {
        val instant = Instant.ofEpochMilli(this)
        return instant.atZone(ZoneOffset.UTC).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
    }

    /**
     * Parses an RFC3339 / ISO-8601 date string to epoch milliseconds.
     * Supports multiple formats:
     * - Standard ISO instant / offset date time (e.g. "2026-07-22T08:33:32Z", "2026-07-22T08:33:32+00:00")
     * - Strings with space instead of 'T' (e.g. "2026-07-22 08:33:32Z")
     * - Strings without offset (e.g. "2026-07-22T08:33:32" or "2026-07-22 08:33:32")
     * - Numeric epoch millisecond strings (e.g. "1721633500000")
     *
     * Returns [fallback] (default 0L) if parsing fails or string is null/blank.
     */
    fun parseRfc3339(dateString: String?, fallback: Long = 0L): Long {
        if (dateString.isNullOrBlank()) return fallback

        val trimmed = dateString.trim()

        // 1. Try numeric epoch millis
        trimmed.toLongOrNull()?.let { millis ->
            if (millis > 0L) return millis
        }

        // 2. Try standard Instant parse
        try {
            return Instant.parse(trimmed).toEpochMilli()
        } catch (_: Exception) {}

        // 3. Try replacing space with 'T' if present
        val withT = if (trimmed.contains(' ')) trimmed.replace(' ', 'T') else trimmed
        if (withT != trimmed) {
            try {
                return Instant.parse(withT).toEpochMilli()
            } catch (_: Exception) {}
        }

        // 4. Try OffsetDateTime parse
        try {
            return OffsetDateTime.parse(withT).toInstant().toEpochMilli()
        } catch (_: Exception) {}

        // 5. Try LocalDateTime (assuming UTC) if missing offset
        try {
            return LocalDateTime.parse(withT).toInstant(ZoneOffset.UTC).toEpochMilli()
        } catch (_: Exception) {}

        return fallback
    }
}
