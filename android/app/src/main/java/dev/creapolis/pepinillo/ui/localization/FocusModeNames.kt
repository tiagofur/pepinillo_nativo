package dev.creapolis.pepinillo.ui.localization

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import dev.creapolis.pepinillo.feature.focus.FocusMode

/**
 * Maps raw, persisted focus-mode names to localized label resources (super-review F3).
 *
 * Session rows, dashboard mode breakdowns and review sheets store the mode as its enum
 * name (e.g. "Pomodoro", "Flow"). Rendering that string directly leaks untranslated
 * English into es/pt markets, so every UI layer that receives a raw mode name should
 * resolve it through this helper and fall back to the raw value only for unknown data.
 */
object FocusModeNames {

    /** Label resource for a raw mode name, or null when the value is not a known mode. */
    @StringRes
    fun labelRes(rawName: String): Int? =
        FocusMode.entries.firstOrNull { it.name == rawName }?.labelRes
}

/** Localized display name for a raw mode name; falls back to the raw value when unknown. */
@Composable
fun localizedModeName(rawName: String): String =
    FocusModeNames.labelRes(rawName)?.let { stringResource(it) } ?: rawName
