package dev.creapolis.pepinillo.feature.focus

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AvTimer
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.ui.graphics.vector.ImageVector

import dev.creapolis.pepinillo.R

enum class FocusMode(
    val labelRes: Int,
    val icon: ImageVector,
    val defaultDisplayTime: String,
    val defaultTotalSeconds: Int?,
    val emoji: String,
) {
    Pomodoro(
        labelRes = R.string.mode_pomodoro,
        icon = Icons.Rounded.Timer,
        defaultDisplayTime = "25:00",
        defaultTotalSeconds = 25 * 60,
        emoji = "🍅",
    ),
    Flow(
        labelRes = R.string.mode_flow,
        icon = Icons.Rounded.AvTimer,
        defaultDisplayTime = "\u221E",
        defaultTotalSeconds = null,
        emoji = "🌊",
    ),
    Blocks(
        labelRes = R.string.mode_blocks,
        icon = Icons.Rounded.ViewAgenda,
        defaultDisplayTime = "60:00",
        defaultTotalSeconds = 60 * 60,
        emoji = "📦",
    ),
    Chrono(
        labelRes = R.string.mode_chrono,
        icon = Icons.Rounded.Speed,
        defaultDisplayTime = "00:00",
        defaultTotalSeconds = null,
        emoji = "⏱️",
    ),
    ;

    val isFreeTier: Boolean get() = this == Pomodoro || this == Chrono
}
