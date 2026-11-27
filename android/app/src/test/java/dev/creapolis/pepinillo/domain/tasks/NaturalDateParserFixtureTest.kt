package dev.creapolis.pepinillo.domain.tasks

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Paths
import java.util.Calendar

/**
 * Issue #994 (S1/S2): the natural-language planned-date grammar asserted
 * against the shared case table versioned in the repo
 * (contracts/fixtures/natural-date-cases-994.json) — the same file the iOS
 * (NaturalDateParserTests) and web suites decode. fixedNow is built in the
 * LOCAL timezone of the test runner, from the components in the fixture
 * (2026-11-27 is a Friday).
 */
class NaturalDateParserFixtureTest {

    @Serializable
    private data class FixedNow(
        val year: Int,
        val month: Int,
        val day: Int,
        val hour: Int,
        val minute: Int,
    )

    @Serializable
    private data class Case(
        val name: String,
        val input: String,
        val expectedTitle: String,
        val expectedDate: JsonElement? = null,
    )

    @Serializable
    private data class Fixture(val fixedNow: FixedNow, val cases: List<Case>)

    private fun loadFixture(): Fixture {
        val repoRoot = Paths.get(System.getProperty("user.dir"), "..", "..").normalize()
        val fixture = repoRoot.resolve("contracts").resolve("fixtures").resolve("natural-date-cases-994.json")
        assertTrue("fixture must exist in the repo: $fixture", Files.exists(fixture))
        return Json { ignoreUnknownKeys = true }.decodeFromString(Fixture.serializer(), Files.readString(fixture))
    }

    /** Local calendar from explicit components (no epoch math). */
    private fun localCal(year: Int, month: Int, day: Int, hour: Int, minute: Int): Calendar =
        Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, hour, minute, 0)
            set(Calendar.MILLISECOND, 0)
        }

    /** Local noon of (fixedNow + [offsetDays]) — noon never crosses a day
     *  boundary under day arithmetic, so cases are deterministic. */
    private fun noon(base: Calendar, offsetDays: Int): Long =
        (base.clone() as Calendar).apply {
            add(Calendar.DAY_OF_MONTH, offsetDays)
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    /** Resolve the fixture's symbolic expectation against shared fixedNow. */
    private fun expectedDayMillis(expected: JsonElement?, now: Calendar): Long? {
        if (expected == null || expected is JsonNull) return null
        if (expected is JsonPrimitive && expected.isString) {
            return when (expected.content) {
                "today" -> noon(now, 0)
                "tomorrow" -> noon(now, 1)
                "dayAfterTomorrow" -> noon(now, 2)
                else -> error("unknown symbolic kind: ${expected.content}")
            }
        }
        val obj = expected.jsonObject
        return when (val kind = obj["kind"]!!.jsonPrimitive.content) {
            "explicit" -> noon(
                localCal(
                    obj["year"]!!.jsonPrimitive.int,
                    obj["month"]!!.jsonPrimitive.int,
                    obj["day"]!!.jsonPrimitive.int,
                    12,
                    0,
                ),
                0,
            )
            "nextWeekday" -> {
                // Next occurrence strictly after today; today → next week (S1).
                val isoToday = when (val dow = now.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.SUNDAY -> 7
                    else -> dow - 1
                }
                var delta = (obj["weekday"]!!.jsonPrimitive.int - isoToday + 7) % 7
                if (delta == 0) delta = 7
                noon(now, delta)
            }
            else -> error("unknown kind: $kind")
        }
    }

    @Test
    fun `grammar matches the shared case table`() {
        val fixture = loadFixture()
        assertTrue("the shared table keeps the whole grammar covered", fixture.cases.size >= 44)
        val now = localCal(
            fixture.fixedNow.year,
            fixture.fixedNow.month,
            fixture.fixedNow.day,
            fixture.fixedNow.hour,
            fixture.fixedNow.minute,
        )

        for (case in fixture.cases) {
            val result = NaturalDateParser.parse(case.input, now.timeInMillis)
            assertEquals("title — ${case.name}", case.expectedTitle, result.title)
            val expected = expectedDayMillis(case.expectedDate, now)
            if (expected == null) {
                assertNull("plannedDate — ${case.name}", result.plannedDate)
            } else {
                assertNotNull("plannedDate — ${case.name}", result.plannedDate)
                assertEquals(
                    "plannedDate — ${case.name}",
                    TaskPlanning.plannedDay(expected),
                    result.plannedDate,
                )
            }
        }
    }

    @Test
    fun `a capture without a trailing date is byte-identical to the input`() {
        val now = Calendar.getInstance()
        val result = NaturalDateParser.parse("  Reunión lunes de estrategia  ", now.timeInMillis)
        assertNull(result.plannedDate)
        assertEquals("Reunión lunes de estrategia", result.title)
    }

    @Test
    fun `plannedDate resolves to local midnight like TaskPlanning`() {
        val friday = localCal(2026, 11, 27, 12, 0)
        val result = NaturalDateParser.parse("Enviar informe el viernes", friday.timeInMillis)
        assertEquals(
            "start of the resolved local day",
            DueDateEncoding.startOfLocalDay(noon(friday, 7)),
            result.plannedDate,
        )
    }
}
