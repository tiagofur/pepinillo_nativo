package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.ui.theme.MotionScheme
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled
import kotlinx.coroutines.delay
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LocalFireDepartment

/**
 * New streak-record celebration (#729). One visual block, two placements:
 *
 * - [StreakRecordHeader] — replaces the SessionJournalSheet header when a completed
 *   session sets a new record (journal-enabled path).
 * - [StreakRecordBanner] — compact non-blocking banner for the journal-disabled path.
 *
 * The block reuses the Dashboard streak hero's exact token pairing
 * (`tertiaryContainer`/`onTertiaryContainer`/`tertiary`) so it reads as "this is the
 * streak". Celebration budget: one halo bloom + one flame pop, ~1 s total, nothing loops.
 * Under reduce-motion everything appears instantly and [onCelebrationShown] fires at once.
 * [onCelebrationShown] is the haptic trigger point (~when the block has appeared).
 */

/** Entry animation shared by both variants; returns the animated progress values. */
@Composable
private fun rememberStreakRecordProgress(onCelebrationShown: () -> Unit): Triple<Float, Float, Float> {
    val reduceMotion = isReduceMotionEnabled()
    var started by remember { mutableStateOf(reduceMotion) }

    LaunchedEffect(Unit) {
        if (!reduceMotion) {
            delay(300) // let the sheet's own enter transition land first
            started = true
            delay(300) // block fully appeared (~600 ms from entry)
        }
        onCelebrationShown()
    }

    val blockAlpha by animateFloatAsState(
        targetValue = if (started) 1f else 0f,
        animationSpec = tween(MotionScheme.DURATION_FADE),
        label = "recordBlockAlpha",
    )
    val flameScale by animateFloatAsState(
        targetValue = if (started) 1f else 0.6f,
        animationSpec = MotionScheme.effectsSpring(reduceMotion),
        label = "recordFlameScale",
    )
    val haloAlpha by animateFloatAsState(
        targetValue = if (started) 0.10f else 0f,
        // bloom to 0.15 then settle at 0.10 — the single celebratory gesture.
        animationSpec = keyframes {
            durationMillis = MotionScheme.DURATION_COLOR
            0.15f at 250
        },
        label = "recordHaloAlpha",
    )
    return Triple(blockAlpha, flameScale, haloAlpha)
}

@Composable
fun StreakRecordHeader(streakDays: Int, onCelebrationShown: () -> Unit) {
    val (blockAlpha, flameScale, haloAlpha) = rememberStreakRecordProgress(onCelebrationShown)
    StreakRecordBlock(
        streakDays = streakDays,
        compact = false,
        blockAlpha = blockAlpha,
        flameScale = flameScale,
        haloAlpha = haloAlpha,
    )
}

@Composable
fun StreakRecordBanner(streakDays: Int, onCelebrationShown: () -> Unit) {
    val (blockAlpha, flameScale, haloAlpha) = rememberStreakRecordProgress(onCelebrationShown)
    val cd = stringResource(R.string.cd_streak_record, streakDays)
    StreakRecordBlock(
        streakDays = streakDays,
        compact = true,
        blockAlpha = blockAlpha,
        flameScale = flameScale,
        haloAlpha = haloAlpha,
        // Banner appears outside any sheet — announce politely for TalkBack.
        extraSemantics = {
            liveRegion = LiveRegionMode.Polite
        },
        contentDescriptionOverride = cd,
    )
}

@Composable
private fun StreakRecordBlock(
    streakDays: Int,
    compact: Boolean,
    blockAlpha: Float,
    flameScale: Float,
    haloAlpha: Float,
    extraSemantics: (androidx.compose.ui.semantics.SemanticsPropertyReceiver.() -> Unit)? = null,
    contentDescriptionOverride: String? = null,
) {
    val container = MaterialTheme.colorScheme.tertiaryContainer
    val onContainer = MaterialTheme.colorScheme.onTertiaryContainer
    val flame = MaterialTheme.colorScheme.tertiary
    val cd = contentDescriptionOverride ?: stringResource(R.string.cd_streak_record, streakDays)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = blockAlpha }
            .clip(PepinilloShapeTokens.card)
            .background(container.copy(alpha = 0.7f))
            .padding(16.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = cd
                extraSemantics?.invoke(this)
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(if (compact) 60.dp else 76.dp)
                    .graphicsLayer { alpha = haloAlpha }
                    .clip(CircleShape)
                    .background(flame),
            )
            Icon(
                imageVector = Icons.Rounded.LocalFireDepartment,
                contentDescription = null, // decorative — the merged CD carries the meaning
                tint = flame,
                modifier = Modifier
                    .size(if (compact) 36.dp else 44.dp)
                    .graphicsLayer {
                        scaleX = flameScale
                        scaleY = flameScale
                    },
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = streakDays.toString(),
            style = if (compact) MaterialTheme.typography.headlineMedium else MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = onContainer,
        )
        Text(
            text = stringResource(R.string.day_streak),
            style = MaterialTheme.typography.labelLarge,
            color = onContainer.copy(alpha = 0.7f),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = pluralStringResource(R.plurals.streak_record_body, streakDays, streakDays),
            style = MaterialTheme.typography.bodyMedium,
            color = onContainer,
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
    }
}
