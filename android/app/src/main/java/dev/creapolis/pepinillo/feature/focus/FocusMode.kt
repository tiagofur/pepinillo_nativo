package dev.creapolis.pepinillo.feature.focus

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AvTimer
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.ui.graphics.vector.ImageVector

enum class FocusMode(
    val label: String,
    val icon: ImageVector,
    val defaultDisplayTime: String,
    val defaultTotalSeconds: Int?,
) {
    Pomodoro(
        label = "Pomodoro",
        icon = Icons.Rounded.Timer,
        defaultDisplayTime = "25:00",
        defaultTotalSeconds = 25 * 60,
    ),
    Flow(
        label = "Flow",
        icon = Icons.Rounded.AvTimer,
        defaultDisplayTime = "\u221E",
        defaultTotalSeconds = null,
    ),
    Blocks(
        label = "Blocks",
        icon = Icons.Rounded.ViewAgenda,
        defaultDisplayTime = "60:00",
        defaultTotalSeconds = 60 * 60,
    ),
    Chrono(
        label = "Chrono",
        icon = Icons.Rounded.Speed,
        defaultDisplayTime = "00:00",
        defaultTotalSeconds = null,
    ),
    ;

    val isFreeTier: Boolean get() = this == Pomodoro || this == Chrono
}
