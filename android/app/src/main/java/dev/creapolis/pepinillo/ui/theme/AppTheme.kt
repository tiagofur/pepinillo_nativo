package dev.creapolis.pepinillo.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

data class AppTheme(
    val id: String,
    val pomodoroColor: Color,
    val flowtimeColor: Color,
    val timeBlockColor: Color,
    val stopwatchColor: Color,
    val streakColor: Color,
    val isFree: Boolean,
) {
    companion object {
        // Classic: fixed brand palette — the original Pepinillo colors. Distinct from
        // MaterialYou which delegates accent colors to the system wallpaper on Android 12+.
        // Previously Classic and MaterialYou had byte-identical colors, making the two
        // themes visually indistinguishable (#405).
        val Classic = AppTheme(
            id = "classic",
            pomodoroColor = Color(0xFFD94236),
            flowtimeColor = Color(0xFF2575D6),
            timeBlockColor = Color(0xFF7B3DCC),
            stopwatchColor = Color(0xFF239E5E),
            streakColor = Color(0xFFE68A12),
            isFree = true,
        )

        val MaterialYou = AppTheme(
            id = "materialYou",
            pomodoroColor = Color(0xFFE84D3D),
            flowtimeColor = Color(0xFF3385EB),
            timeBlockColor = Color(0xFF8F45DD),
            stopwatchColor = Color(0xFF2DB870),
            streakColor = Color(0xFFFF991A),
            isFree = true,
        )

        // Sprint 8 (#494): Forest/Ocean/Sunset accents are now derived from their own M3
        // ColorSchemes (see Theme.kt) via [fromColorScheme], so the focus-mode accents stay
        // coherent with the surfaces/containers of each theme. Classic/MaterialYou keep their
        // hand-tuned brand accents (criterion: Free users see no unexpected change).
        val Forest = fromColorScheme(
            id = "forest",
            scheme = ForestDarkColorScheme,
            isFree = false,
        )

        val Ocean = fromColorScheme(
            id = "ocean",
            scheme = OceanDarkColorScheme,
            isFree = false,
        )

        val Sunset = fromColorScheme(
            id = "sunset",
            scheme = SunsetDarkColorScheme,
            isFree = false,
        )

        val all = listOf(MaterialYou, Classic, Forest, Ocean, Sunset)
        fun named(id: String) = all.firstOrNull { it.id == id } ?: MaterialYou

        /**
         * Derives an [AppTheme]'s focus-mode accents from a generated [ColorScheme], so the accents
         * stay visually coherent with the theme's surfaces and containers (Sprint 8, #494).
         *
         * Mapping (mirrors the doc's proposal):
         *  - pomodoroColor  ← error           (warm/red urgency)
         *  - flowtimeColor  ← primary         (the theme's identity hue)
         *  - timeBlockColor ← tertiary        (complementary)
         *  - stopwatchColor ← secondary       (analog)
         *  - streakColor    ← tertiaryContainer (warm container)
         */
        fun fromColorScheme(
            id: String,
            scheme: ColorScheme,
            isFree: Boolean = false,
        ): AppTheme = AppTheme(
            id = id,
            pomodoroColor = scheme.error,
            flowtimeColor = scheme.primary,
            timeBlockColor = scheme.tertiary,
            stopwatchColor = scheme.secondary,
            streakColor = scheme.tertiaryContainer,
            isFree = isFree,
        )
    }
}

val LocalAppTheme = staticCompositionLocalOf { AppTheme.MaterialYou }
