package dev.creapolis.pepinillo.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle

/**
 * Number roll for live counters (#776 Batch B): new values slide up under the
 * old ones and crossfade — the Material 3 counterpart of iOS numericText.
 * Snappy, no bounce: counters are information, not celebration.
 */
@Composable
fun AnimatedCounter(
    text: String,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.titleLarge,
    color: Color = MaterialTheme.colorScheme.onSurface,
    fontWeight: FontWeight? = null,
) {
    // Fade-only, deliberately subtle (#776 Batch B feedback): a timer must
    // never demand attention — the user is focusing. No slide, ~150 ms.
    AnimatedContent(
        targetState = text,
        transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(150)) },
        label = "counter",
        modifier = modifier,
    ) { value ->
        Text(
            text = value,
            style = style,
            color = color,
            fontWeight = fontWeight,
        )
    }
}
