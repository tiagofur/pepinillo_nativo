package dev.creapolis.pepinillo.ui.localization

import dev.creapolis.pepinillo.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Unit tests for the raw-name → localized-label mapping (super-review F3). Mode names are
 * persisted as raw enum strings and rendered in dashboard breakdowns, calendar session rows
 * and review sheets; unmapped values must fall back rather than crash.
 */
class FocusModeNamesTest {

    @Test
    fun `maps every persisted mode name to its label resource`() {
        assertEquals(R.string.mode_pomodoro, FocusModeNames.labelRes("Pomodoro"))
        assertEquals(R.string.mode_flow, FocusModeNames.labelRes("Flow"))
        assertEquals(R.string.mode_blocks, FocusModeNames.labelRes("Blocks"))
        assertEquals(R.string.mode_chrono, FocusModeNames.labelRes("Chrono"))
    }

    @Test
    fun `returns null for unknown mode names`() {
        assertNull(FocusModeNames.labelRes("DeepWork"))
        assertNull(FocusModeNames.labelRes(""))
        assertNull(FocusModeNames.labelRes("pomodoro")) // case-sensitive: only exact enum names
    }
}
