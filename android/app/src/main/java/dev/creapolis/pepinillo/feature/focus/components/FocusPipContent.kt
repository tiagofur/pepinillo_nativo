package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.feature.focus.FocusViewModel
import dev.creapolis.pepinillo.ui.theme.colorScheme

/** Pure PiP decisions, kept out of the Activity so they are unit-testable. */
object FocusPipLogic {
    /**
     * The Activity may be recreated (lock/unlock, config change) while still floating; the
     * Compose flag then starts at `false`. Trust either source so the nav bar never takes
     * over the tiny PiP window.
     */
    fun resolveEffectivePipMode(statePipMode: Boolean, activityInPipMode: Boolean): Boolean =
        statePipMode || activityInPipMode

    fun shouldAutoEnterPip(status: TimerStatus): Boolean = status == TimerStatus.Running
}

/** Entry point used by the app shell while the Activity is in Picture-in-Picture. */
@Composable
fun FocusPipContent(
    modifier: Modifier = Modifier,
    viewModel: FocusViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val ringState by viewModel.ringState.collectAsState()
    val colors = uiState.selectedMode.colorScheme(uiState.currentPhase)

    val label = uiState.linkedTaskName
        ?: if (uiState.selectedMode == FocusMode.Pomodoro && uiState.currentPhase == FocusPhase.Work) {
            stringResource(R.string.phase_focus_numbered, uiState.completedSessions + 1)
        } else {
            stringResource(uiState.phaseLabelRes)
        }

    FocusPipCard(
        label = label,
        displayTime = ringState.displayTime,
        progress = if (uiState.selectedMode.defaultTotalSeconds != null) ringState.progress else null,
        isPaused = ringState.isPaused,
        accentColor = colors.accentColor,
        modeIcon = uiState.selectedMode.icon,
        modifier = modifier,
    )
}

/**
 * Minimal PiP layout: a one-line label, the time as the only hero element, and a thin linear
 * progress bar. No ring: a circle wastes a 16:9 window and clips.
 */
@Composable
fun FocusPipCard(
    label: String,
    displayTime: String,
    progress: Float?,
    isPaused: Boolean,
    accentColor: Color,
    modeIcon: androidx.compose.ui.graphics.vector.ImageVector,
    modifier: Modifier = Modifier,
) {
    val pausedText = stringResource(R.string.pip_paused_badge)
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .background(accentColor.copy(alpha = 0.10f))
            .clearAndSetSemantics { contentDescription = "$label $displayTime" },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp)
                .padding(top = 8.dp, bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Start,
            ) {
                Icon(
                    imageVector = modeIcon,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(14.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (isPaused) {
                    Text(
                        text = pausedText.uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = accentColor,
                        maxLines = 1,
                    )
                }
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = displayTime,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"),
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(if (progress != null) 4.dp else 2.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(progress?.coerceIn(0f, 1f) ?: 1f)
                        .background(accentColor.copy(alpha = if (progress != null) 1f else 0.5f)),
                )
            }
        }
    }
}
