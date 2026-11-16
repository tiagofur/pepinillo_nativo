package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.celebration.Milestone

/**
 * Full-screen milestone celebration (#776 Batch D — Material 3 expression of
 * the iOS #774 overlay): dim scrim, a single spring pop for the emoji, title
 * and subtitle, and a "keep going" button. Tap anywhere dismisses. Material
 * restraint over confetti: the haptic waveform fires from the ViewModel.
 */
@Composable
fun MilestoneCelebrationOverlay(
    milestone: Milestone,
    onDismiss: () -> Unit,
) {
    val pop = remember { Animatable(0.6f) }
    LaunchedEffect(milestone) {
        pop.animateTo(
            targetValue = 1f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium,
            ),
        )
    }

    val emoji = milestoneEmoji(milestone)
    val title = milestoneTitle(milestone)
    val subtitle = milestoneSubtitle(milestone)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.55f))
            .clickable { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .padding(horizontal = 32.dp)
                .graphicsLayer {
                    scaleX = pop.value
                    scaleY = pop.value
                    alpha = pop.value.coerceIn(0f, 1f)
                },
        ) {
            Text(text = emoji, fontSize = 56.sp)
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimary,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.85f),
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(20.dp))
            Button(onClick = onDismiss) {
                Text(text = stringResource(R.string.celebration_keep_going))
            }
        }
    }
}

private fun milestoneEmoji(milestone: Milestone): String = when (milestone) {
    is Milestone.FirstSession -> "🎯"
    is Milestone.StreakDay -> when {
        milestone.days >= 30 -> "🏆"
        milestone.days >= 14 -> "🔥"
        else -> "⚡"
    }
    is Milestone.SessionCount -> when {
        milestone.count >= 100 -> "💎"
        milestone.count >= 50 -> "🌟"
        else -> "✨"
    }
    is Milestone.PersonalBest -> "🚀"
}

@Composable
private fun milestoneTitle(milestone: Milestone): String = when (milestone) {
    is Milestone.FirstSession -> stringResource(R.string.celebration_first_title)
    is Milestone.StreakDay ->
        stringResource(R.string.celebration_streak_title, milestone.days)
    is Milestone.SessionCount ->
        stringResource(R.string.celebration_sessions_title, milestone.count)
    is Milestone.PersonalBest ->
        stringResource(R.string.celebration_best_title, milestone.minutes)
}

@Composable
private fun milestoneSubtitle(milestone: Milestone): String = when (milestone) {
    is Milestone.FirstSession -> stringResource(R.string.celebration_first_subtitle)
    is Milestone.StreakDay -> when (milestone.days) {
        in 1..13 -> stringResource(R.string.celebration_streak_7_subtitle)
        in 14..29 -> stringResource(R.string.celebration_streak_14_subtitle)
        else -> stringResource(R.string.celebration_streak_30_subtitle)
    }
    is Milestone.SessionCount -> when {
        milestone.count >= 100 -> stringResource(R.string.celebration_sessions_100_subtitle)
        milestone.count >= 50 -> stringResource(R.string.celebration_sessions_50_subtitle)
        else -> stringResource(R.string.celebration_sessions_10_subtitle)
    }
    is Milestone.PersonalBest ->
        stringResource(R.string.celebration_best_subtitle, milestone.minutes)
}

