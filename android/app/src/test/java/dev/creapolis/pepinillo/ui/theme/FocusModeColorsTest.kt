package dev.creapolis.pepinillo.ui.theme

import androidx.compose.ui.graphics.Color
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.feature.focus.FocusMode
import org.junit.Assert.assertEquals
import org.junit.Test

class FocusModeColorsTest {

    @Test
    fun testOnAccentColor_lightAccent_returnsBlack() {
        val sunsetYellow = Color(0xFFFFB74D)
        assertEquals(Color.Black, sunsetYellow.onAccentColor())

        val oceanCyan = Color(0xFF4DD0E1)
        assertEquals(Color.Black, oceanCyan.onAccentColor())

        val brightWhite = Color.White
        assertEquals(Color.Black, brightWhite.onAccentColor())
    }

    @Test
    fun testOnAccentColor_darkAccent_returnsWhite() {
        val darkRed = Color(0xFFBA1A1A)
        assertEquals(Color.White, darkRed.onAccentColor())

        val darkBlue = Color(0xFF0061A4)
        assertEquals(Color.White, darkBlue.onAccentColor())

        val pureBlack = Color.Black
        assertEquals(Color.White, pureBlack.onAccentColor())
    }
}
