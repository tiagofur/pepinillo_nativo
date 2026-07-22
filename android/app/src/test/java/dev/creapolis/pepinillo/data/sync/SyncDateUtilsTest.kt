package dev.creapolis.pepinillo.data.sync

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class SyncDateUtilsTest {

    @Test
    fun `parseRfc3339 parses standard ISO 8601 UTC instant`() {
        val iso = "2026-07-22T08:33:32Z"
        val expected = Instant.parse(iso).toEpochMilli()
        val actual = SyncDateUtils.parseRfc3339(iso)
        assertEquals(expected, actual)
    }

    @Test
    fun `parseRfc3339 parses ISO date with offset`() {
        val iso = "2026-07-22T08:33:32+02:00"
        val expected = Instant.parse("2026-07-22T06:33:32Z").toEpochMilli()
        val actual = SyncDateUtils.parseRfc3339(iso)
        assertEquals(expected, actual)
    }

    @Test
    fun `parseRfc3339 parses date string with space instead of T`() {
        val spaceDate = "2026-07-22 08:33:32Z"
        val expected = Instant.parse("2026-07-22T08:33:32Z").toEpochMilli()
        val actual = SyncDateUtils.parseRfc3339(spaceDate)
        assertEquals(expected, actual)
    }

    @Test
    fun `parseRfc3339 parses date string missing offset assuming UTC`() {
        val noOffset = "2026-07-22T08:33:32"
        val expected = Instant.parse("2026-07-22T08:33:32Z").toEpochMilli()
        val actual = SyncDateUtils.parseRfc3339(noOffset)
        assertEquals(expected, actual)
    }

    @Test
    fun `parseRfc3339 parses date string with space and missing offset assuming UTC`() {
        val spaceNoOffset = "2026-07-22 08:33:32"
        val expected = Instant.parse("2026-07-22T08:33:32Z").toEpochMilli()
        val actual = SyncDateUtils.parseRfc3339(spaceNoOffset)
        assertEquals(expected, actual)
    }

    @Test
    fun `parseRfc3339 parses numeric epoch millis string`() {
        val millisString = "1721633500000"
        val actual = SyncDateUtils.parseRfc3339(millisString)
        assertEquals(1721633500000L, actual)
    }

    @Test
    fun `parseRfc3339 returns fallback on null or blank or invalid string`() {
        val fallback = 123456789L
        assertEquals(fallback, SyncDateUtils.parseRfc3339(null, fallback = fallback))
        assertEquals(fallback, SyncDateUtils.parseRfc3339("", fallback = fallback))
        assertEquals(fallback, SyncDateUtils.parseRfc3339("   ", fallback = fallback))
        assertEquals(fallback, SyncDateUtils.parseRfc3339("not-a-date", fallback = fallback))
    }

    @Test
    fun `toRfc3339 formats epoch millis to ISO string`() {
        val millis = 1721633500000L
        val formatted = SyncDateUtils.run { millis.toRfc3339() }
        val parsedBack = SyncDateUtils.parseRfc3339(formatted)
        assertEquals(millis, parsedBack)
    }
}
