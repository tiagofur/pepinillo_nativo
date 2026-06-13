package dev.creapolis.pepinillo.feature.dashboard.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ---------------------------------------------------------------------------
// Pure functions — testable without Compose
// ---------------------------------------------------------------------------

/** Returns the display text for the streak hero number. */
fun getStreakDisplayText(currentStreak: Int): String {
    return if (currentStreak == 0) "Start your streak!" else currentStreak.toString()
}

/** Whether the glow animation should be active. */
fun shouldShowGlow(currentStreak: Int): Boolean = currentStreak > 0

/** Formats period stats as a compact string like "2h 30m · 5 sessions". */
fun formatPeriodStats(minutes: Int, sessions: Int): String {
    val hours = minutes / 60
    val mins = minutes % 60
    val timeStr = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
    val sessionLabel = if (sessions == 1) "session" else "sessions"
    return "$timeStr \u00B7 $sessions $sessionLabel"
}

// ---------------------------------------------------------------------------
// StreakHeroCard composable
// ---------------------------------------------------------------------------

@Composable
fun StreakHeroCard(
    currentStreak: Int,
    bestStreak: Int,
    streakProtectionApplied: Boolean,
    periodMinutes: Int,
    periodSessions: Int,
    modifier: Modifier = Modifier,
) {
    val showGlow = shouldShowGlow(currentStreak)
    val primaryColor = MaterialTheme.colorScheme.primary
    val surfaceVariantColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)

    // Glow animation: alpha oscillates 0.3–0.8 over 2000ms
    val infiniteTransition = rememberInfiniteTransition(label = "streakGlow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.8f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000, easing = EaseInOut),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "glowAlpha",
    )

    val cardShape = RoundedCornerShape(28.dp)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(surfaceVariantColor)
            .then(
                if (showGlow) {
                    Modifier.border(
                        width = 2.dp,
                        brush = Brush.linearGradient(
                            colors = listOf(
                                primaryColor.copy(alpha = glowAlpha),
                                primaryColor.copy(alpha = glowAlpha * 0.6f),
                            ),
                        ),
                        shape = cardShape,
                    )
                } else {
                    Modifier
                },
            )
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Fire icon + streak number
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (showGlow) {
                Icon(
                    imageVector = Icons.Rounded.LocalFireDepartment,
                    contentDescription = "Streak",
                    tint = primaryColor,
                    modifier = Modifier.size(40.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                text = getStreakDisplayText(currentStreak),
                style = if (showGlow) {
                    MaterialTheme.typography.displayLarge.copy(
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    )
                } else {
                    MaterialTheme.typography.headlineMedium.copy(
                        fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                    )
                },
                color = if (showGlow) primaryColor else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // "day streak" label
        if (showGlow) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "day streak",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Protection badge
        if (showGlow && streakProtectionApplied) {
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Rounded.Shield,
                    contentDescription = "Streak protection active",
                    tint = MaterialTheme.colorScheme.tertiary,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "Protected",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
        }

        // Compact stats row: focus time + sessions
        if (showGlow) {
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Rounded.Schedule,
                        contentDescription = "Focus time",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = formatPeriodStats(periodMinutes, periodSessions),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
