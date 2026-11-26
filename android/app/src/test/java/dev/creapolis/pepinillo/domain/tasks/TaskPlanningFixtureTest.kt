package dev.creapolis.pepinillo.domain.tasks

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Paths
import java.util.Calendar

/**
 * Issue #991 (S3): the unified «Hoy» rule asserted against the shared case
 * table versioned in the repo (contracts/fixtures/task-planning-cases-991.json)
 * — the same file the iOS (TaskPlanningTests) and web suites decode.
 */
class TaskPlanningFixtureTest {

    @Serializable
    private data class Expected(
        val today: Boolean,
        val postponed: Boolean,
        val upcoming: Boolean,
        val inbox: Boolean,
    )

    @Serializable
    private data class Case(
        val name: String,
        val planned: Long? = null,
        val due: Long? = null,
        val status: String,
        val legacyScheduledForToday: Boolean? = null,
        val recurringInstance: Boolean? = null,
        val expected: Expected,
    )

    @Serializable
    private data class Fixture(val cases: List<Case>)

    private fun loadFixture(): List<Case> {
        val repoRoot = Paths.get(System.getProperty("user.dir"), "..", "..").normalize()
        val fixture = repoRoot.resolve("contracts").resolve("fixtures").resolve("task-planning-cases-991.json")
        assertTrue("fixture must exist in the repo: $fixture", Files.exists(fixture))
        return Json { ignoreUnknownKeys = true }.decodeFromString(Fixture.serializer(), Files.readString(fixture)).cases
    }

    /** Local calendar at noon of (today + [offsetDays]) — noon never crosses a
     *  day boundary under day arithmetic, so cases are deterministic. */
    private fun dayMillis(offsetDays: Int): Long {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, offsetDays)
        cal.set(Calendar.HOUR_OF_DAY, 12)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    @Test
    fun `unified rule matches the shared case table`() {
        val cases = loadFixture()
        assertTrue("the shared table keeps growing with regressions", cases.size >= 16)
        val now = dayMillis(0)

        for (case in cases) {
            val planned = case.planned?.let { TaskPlanning.plannedDay(dayMillis(it.toInt())) }
            val due = case.due?.let { TaskPlanning.plannedDay(dayMillis(it.toInt())) }
            val bucket = TaskPlanning.bucket(
                plannedDate = planned,
                dueDate = due,
                scheduledForToday = case.legacyScheduledForToday ?: false,
                isCompleted = case.status == "completed",
                now = now,
            )
            when (bucket) {
                is TaskPlanning.Bucket.Today -> {
                    assertTrue("today — ${case.name}", case.expected.today)
                    assertEquals("postponed — ${case.name}", case.expected.postponed, bucket.postponed)
                    assertFalse("not upcoming — ${case.name}", case.expected.upcoming)
                    assertFalse("not inbox — ${case.name}", case.expected.inbox)
                }
                TaskPlanning.Bucket.Upcoming -> {
                    assertTrue("upcoming — ${case.name}", case.expected.upcoming)
                    assertFalse("not today — ${case.name}", case.expected.today)
                    assertFalse("not inbox — ${case.name}", case.expected.inbox)
                }
                TaskPlanning.Bucket.Inbox -> {
                    assertTrue("inbox — ${case.name}", case.expected.inbox)
                    assertFalse("not today — ${case.name}", case.expected.today)
                    assertFalse("not upcoming — ${case.name}", case.expected.upcoming)
                }
                TaskPlanning.Bucket.Completed -> {
                    assertEquals("completed only for completed — ${case.name}", "completed", case.status)
                    assertFalse("not today — ${case.name}", case.expected.today)
                    assertFalse("not upcoming — ${case.name}", case.expected.upcoming)
                    assertFalse("not inbox — ${case.name}", case.expected.inbox)
                }
            }
        }
    }

    @Test
    fun `past plan stays today and turns postponed after midnight (S6)`() {
        val yesterday = TaskPlanning.plannedDay(dayMillis(-1))
        val tomorrow = dayMillis(1)

        val todayBucket = TaskPlanning.bucket(plannedDate = yesterday, dueDate = null, isCompleted = false, now = dayMillis(0))
        assertTrue("yesterday's plan is in «Hoy» today", todayBucket is TaskPlanning.Bucket.Today)
        assertTrue("it is postponed", (todayBucket as TaskPlanning.Bucket.Today).postponed)

        val afterMidnight = TaskPlanning.bucket(plannedDate = yesterday, dueDate = null, isCompleted = false, now = tomorrow)
        assertTrue("still in «Hoy» the next day (never rolls back to inbox)", afterMidnight is TaskPlanning.Bucket.Today)
        assertTrue("and postponed", (afterMidnight as TaskPlanning.Bucket.Today).postponed)
    }

    @Test
    fun `plannedDay normalizes to local midnight (S1)`() {
        val noon = dayMillis(0)
        val planned = TaskPlanning.plannedDay(noon)
        assertEquals("start of the same local day", DueDateEncoding.startOfLocalDay(noon), planned)
    }
}
