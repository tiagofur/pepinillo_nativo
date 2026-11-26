package dev.creapolis.pepinillo.domain.tasks

import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Issue #990 (S1): every platform asserts its hour → energy engine against
 * the same 24-hour fixture versioned in the repo (contracts/fixtures).
 */
class EnergySuggestionTest {

    @Test
    fun `suggestEnergy matches the shared 24-hour fixture table`() {
        val repoRoot = Paths.get(System.getProperty("user.dir"), "..", "..").normalize()
        val fixture = repoRoot.resolve("contracts").resolve("fixtures").resolve("energy-hours-989.json")
        assertTrue("fixture must exist: $fixture", Files.exists(fixture))
        val json = Files.readString(fixture)
        val entries = Regex("\"hour\"\\s*:\\s*(\\d+)").findAll(json).map { it.groupValues[1].toInt() }.toList()
        val levels = Regex("\"level\"\\s*:\\s*\"(\\w+)\"").findAll(json).map { it.groupValues[1] }.toList()
        assertEquals(24, entries.size)
        entries.zip(levels).forEach { (hour, level) ->
            // canonical vocabulary (deep/shallow/admin) → Android labels
            val expected = when (level) {
                "deep" -> EnergyLevel.Deep
                "shallow" -> EnergyLevel.Light
                else -> EnergyLevel.Regular
            }
            assertEquals("hour $hour", expected, EnergySuggestion.suggestedLevel(hour))
        }
    }
}
