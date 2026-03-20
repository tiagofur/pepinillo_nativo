package dev.creapolis.pepinillo.ui.theme

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
        val Classic = AppTheme(
            id = "classic",
            pomodoroColor = Color(0xFFE84D3D),
            flowtimeColor = Color(0xFF3385EB),
            timeBlockColor = Color(0xFF8F45DD),
            stopwatchColor = Color(0xFF2DB870),
            streakColor = Color(0xFFFF991A),
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

        val Forest = AppTheme(
            id = "forest",
            pomodoroColor = Color(0xFF2E8C3A),
            flowtimeColor = Color(0xFF216A4A),
            timeBlockColor = Color(0xFF578F33),
            stopwatchColor = Color(0xFF84B54D),
            streakColor = Color(0xFF99C626),
            isFree = false,
        )

        val Ocean = AppTheme(
            id = "ocean",
            pomodoroColor = Color(0xFF0082CA),
            flowtimeColor = Color(0xFF0DABD9),
            timeBlockColor = Color(0xFF1F5CB5),
            stopwatchColor = Color(0xFF00BDD3),
            streakColor = Color(0xFF00CDF2),
            isFree = false,
        )

        val Sunset = AppTheme(
            id = "sunset",
            pomodoroColor = Color(0xFFED5C26),
            flowtimeColor = Color(0xFFF5A11A),
            timeBlockColor = Color(0xFFCD407A),
            stopwatchColor = Color(0xFFF5C239),
            streakColor = Color(0xFFFFB31F),
            isFree = false,
        )

        val all = listOf(MaterialYou, Classic, Forest, Ocean, Sunset)
        fun named(id: String) = all.firstOrNull { it.id == id } ?: MaterialYou
    }
}

val LocalAppTheme = staticCompositionLocalOf { AppTheme.MaterialYou }
