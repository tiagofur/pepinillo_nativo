package dev.creapolis.pepinillo.ui.theme

import android.os.Build
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext

// Sprint 8 (#494): one full M3 ColorScheme per theme. The "base" scheme (Pepinillo Green) is the
// fallback for MaterialYou (when dynamic color is off) and Classic; Forest/Ocean/Sunset each ship
// their own derived scheme so the whole UI — not just the focus-mode accents — follows the theme.

// ─────────────────────────── Base (Pepinillo Green) ────────────────────────────────
private val LightColorScheme = lightColorScheme(
    primary = md_theme_light_primary,
    onPrimary = md_theme_light_onPrimary,
    primaryContainer = md_theme_light_primaryContainer,
    onPrimaryContainer = md_theme_light_onPrimaryContainer,
    secondary = md_theme_light_secondary,
    onSecondary = md_theme_light_onSecondary,
    secondaryContainer = md_theme_light_secondaryContainer,
    onSecondaryContainer = md_theme_light_onSecondaryContainer,
    tertiary = md_theme_light_tertiary,
    onTertiary = md_theme_light_onTertiary,
    tertiaryContainer = md_theme_light_tertiaryContainer,
    onTertiaryContainer = md_theme_light_onTertiaryContainer,
    error = md_theme_light_error,
    onError = md_theme_light_onError,
    errorContainer = md_theme_light_errorContainer,
    onErrorContainer = md_theme_light_onErrorContainer,
    background = md_theme_light_background,
    onBackground = md_theme_light_onBackground,
    surface = md_theme_light_surface,
    onSurface = md_theme_light_onSurface,
    surfaceVariant = md_theme_light_surfaceVariant,
    onSurfaceVariant = md_theme_light_onSurfaceVariant,
    outline = md_theme_light_outline,
    outlineVariant = md_theme_light_outlineVariant,
    inverseSurface = md_theme_light_inverseSurface,
    inverseOnSurface = md_theme_light_inverseOnSurface,
    inversePrimary = md_theme_light_inversePrimary,
    surfaceTint = md_theme_light_surfaceTint,
)

private val DarkColorScheme = darkColorScheme(
    primary = md_theme_dark_primary,
    onPrimary = md_theme_dark_onPrimary,
    primaryContainer = md_theme_dark_primaryContainer,
    onPrimaryContainer = md_theme_dark_onPrimaryContainer,
    secondary = md_theme_dark_secondary,
    onSecondary = md_theme_dark_onSecondary,
    secondaryContainer = md_theme_dark_secondaryContainer,
    onSecondaryContainer = md_theme_dark_onSecondaryContainer,
    tertiary = md_theme_dark_tertiary,
    onTertiary = md_theme_dark_onTertiary,
    tertiaryContainer = md_theme_dark_tertiaryContainer,
    onTertiaryContainer = md_theme_dark_onTertiaryContainer,
    error = md_theme_dark_error,
    onError = md_theme_dark_onError,
    errorContainer = md_theme_dark_errorContainer,
    onErrorContainer = md_theme_dark_onErrorContainer,
    background = md_theme_dark_background,
    onBackground = md_theme_dark_onBackground,
    surface = md_theme_dark_surface,
    onSurface = md_theme_dark_onSurface,
    surfaceVariant = md_theme_dark_surfaceVariant,
    onSurfaceVariant = md_theme_dark_onSurfaceVariant,
    outline = md_theme_dark_outline,
    outlineVariant = md_theme_dark_outlineVariant,
    inverseSurface = md_theme_dark_inverseSurface,
    inverseOnSurface = md_theme_dark_inverseOnSurface,
    inversePrimary = md_theme_dark_inversePrimary,
    surfaceTint = md_theme_dark_surfaceTint,
)

// ─────────────────────────── Forest ─────────────────────────────────────────────────
internal val ForestLightColorScheme = lightColorScheme(
    primary = md_theme_forest_light_primary,
    onPrimary = md_theme_forest_light_onPrimary,
    primaryContainer = md_theme_forest_light_primaryContainer,
    onPrimaryContainer = md_theme_forest_light_onPrimaryContainer,
    secondary = md_theme_forest_light_secondary,
    onSecondary = md_theme_forest_light_onSecondary,
    secondaryContainer = md_theme_forest_light_secondaryContainer,
    onSecondaryContainer = md_theme_forest_light_onSecondaryContainer,
    tertiary = md_theme_forest_light_tertiary,
    onTertiary = md_theme_forest_light_onTertiary,
    tertiaryContainer = md_theme_forest_light_tertiaryContainer,
    onTertiaryContainer = md_theme_forest_light_onTertiaryContainer,
    error = md_theme_forest_light_error,
    onError = md_theme_forest_light_onError,
    errorContainer = md_theme_forest_light_errorContainer,
    onErrorContainer = md_theme_forest_light_onErrorContainer,
    background = md_theme_forest_light_background,
    onBackground = md_theme_forest_light_onBackground,
    surface = md_theme_forest_light_surface,
    onSurface = md_theme_forest_light_onSurface,
    surfaceVariant = md_theme_forest_light_surfaceVariant,
    onSurfaceVariant = md_theme_forest_light_onSurfaceVariant,
    outline = md_theme_forest_light_outline,
    outlineVariant = md_theme_forest_light_outlineVariant,
)

internal val ForestDarkColorScheme = darkColorScheme(
    primary = md_theme_forest_dark_primary,
    onPrimary = md_theme_forest_dark_onPrimary,
    primaryContainer = md_theme_forest_dark_primaryContainer,
    onPrimaryContainer = md_theme_forest_dark_onPrimaryContainer,
    secondary = md_theme_forest_dark_secondary,
    onSecondary = md_theme_forest_dark_onSecondary,
    secondaryContainer = md_theme_forest_dark_secondaryContainer,
    onSecondaryContainer = md_theme_forest_dark_onSecondaryContainer,
    tertiary = md_theme_forest_dark_tertiary,
    onTertiary = md_theme_forest_dark_onTertiary,
    tertiaryContainer = md_theme_forest_dark_tertiaryContainer,
    onTertiaryContainer = md_theme_forest_dark_onTertiaryContainer,
    error = md_theme_forest_dark_error,
    onError = md_theme_forest_dark_onError,
    errorContainer = md_theme_forest_dark_errorContainer,
    onErrorContainer = md_theme_forest_dark_onErrorContainer,
    background = md_theme_forest_dark_background,
    onBackground = md_theme_forest_dark_onBackground,
    surface = md_theme_forest_dark_surface,
    onSurface = md_theme_forest_dark_onSurface,
    surfaceVariant = md_theme_forest_dark_surfaceVariant,
    onSurfaceVariant = md_theme_forest_dark_onSurfaceVariant,
    outline = md_theme_forest_dark_outline,
    outlineVariant = md_theme_forest_dark_outlineVariant,
)

// ─────────────────────────── Ocean ──────────────────────────────────────────────────
internal val OceanLightColorScheme = lightColorScheme(
    primary = md_theme_ocean_light_primary,
    onPrimary = md_theme_ocean_light_onPrimary,
    primaryContainer = md_theme_ocean_light_primaryContainer,
    onPrimaryContainer = md_theme_ocean_light_onPrimaryContainer,
    secondary = md_theme_ocean_light_secondary,
    onSecondary = md_theme_ocean_light_onSecondary,
    secondaryContainer = md_theme_ocean_light_secondaryContainer,
    onSecondaryContainer = md_theme_ocean_light_onSecondaryContainer,
    tertiary = md_theme_ocean_light_tertiary,
    onTertiary = md_theme_ocean_light_onTertiary,
    tertiaryContainer = md_theme_ocean_light_tertiaryContainer,
    onTertiaryContainer = md_theme_ocean_light_onTertiaryContainer,
    error = md_theme_ocean_light_error,
    onError = md_theme_ocean_light_onError,
    errorContainer = md_theme_ocean_light_errorContainer,
    onErrorContainer = md_theme_ocean_light_onErrorContainer,
    background = md_theme_ocean_light_background,
    onBackground = md_theme_ocean_light_onBackground,
    surface = md_theme_ocean_light_surface,
    onSurface = md_theme_ocean_light_onSurface,
    surfaceVariant = md_theme_ocean_light_surfaceVariant,
    onSurfaceVariant = md_theme_ocean_light_onSurfaceVariant,
    outline = md_theme_ocean_light_outline,
    outlineVariant = md_theme_ocean_light_outlineVariant,
)

internal val OceanDarkColorScheme = darkColorScheme(
    primary = md_theme_ocean_dark_primary,
    onPrimary = md_theme_ocean_dark_onPrimary,
    primaryContainer = md_theme_ocean_dark_primaryContainer,
    onPrimaryContainer = md_theme_ocean_dark_onPrimaryContainer,
    secondary = md_theme_ocean_dark_secondary,
    onSecondary = md_theme_ocean_dark_onSecondary,
    secondaryContainer = md_theme_ocean_dark_secondaryContainer,
    onSecondaryContainer = md_theme_ocean_dark_onSecondaryContainer,
    tertiary = md_theme_ocean_dark_tertiary,
    onTertiary = md_theme_ocean_dark_onTertiary,
    tertiaryContainer = md_theme_ocean_dark_tertiaryContainer,
    onTertiaryContainer = md_theme_ocean_dark_onTertiaryContainer,
    error = md_theme_ocean_dark_error,
    onError = md_theme_ocean_dark_onError,
    errorContainer = md_theme_ocean_dark_errorContainer,
    onErrorContainer = md_theme_ocean_dark_onErrorContainer,
    background = md_theme_ocean_dark_background,
    onBackground = md_theme_ocean_dark_onBackground,
    surface = md_theme_ocean_dark_surface,
    onSurface = md_theme_ocean_dark_onSurface,
    surfaceVariant = md_theme_ocean_dark_surfaceVariant,
    onSurfaceVariant = md_theme_ocean_dark_onSurfaceVariant,
    outline = md_theme_ocean_dark_outline,
    outlineVariant = md_theme_ocean_dark_outlineVariant,
)

// ─────────────────────────── Sunset ─────────────────────────────────────────────────
internal val SunsetLightColorScheme = lightColorScheme(
    primary = md_theme_sunset_light_primary,
    onPrimary = md_theme_sunset_light_onPrimary,
    primaryContainer = md_theme_sunset_light_primaryContainer,
    onPrimaryContainer = md_theme_sunset_light_onPrimaryContainer,
    secondary = md_theme_sunset_light_secondary,
    onSecondary = md_theme_sunset_light_onSecondary,
    secondaryContainer = md_theme_sunset_light_secondaryContainer,
    onSecondaryContainer = md_theme_sunset_light_onSecondaryContainer,
    tertiary = md_theme_sunset_light_tertiary,
    onTertiary = md_theme_sunset_light_onTertiary,
    tertiaryContainer = md_theme_sunset_light_tertiaryContainer,
    onTertiaryContainer = md_theme_sunset_light_onTertiaryContainer,
    error = md_theme_sunset_light_error,
    onError = md_theme_sunset_light_onError,
    errorContainer = md_theme_sunset_light_errorContainer,
    onErrorContainer = md_theme_sunset_light_onErrorContainer,
    background = md_theme_sunset_light_background,
    onBackground = md_theme_sunset_light_onBackground,
    surface = md_theme_sunset_light_surface,
    onSurface = md_theme_sunset_light_onSurface,
    surfaceVariant = md_theme_sunset_light_surfaceVariant,
    onSurfaceVariant = md_theme_sunset_light_onSurfaceVariant,
    outline = md_theme_sunset_light_outline,
    outlineVariant = md_theme_sunset_light_outlineVariant,
)

internal val SunsetDarkColorScheme = darkColorScheme(
    primary = md_theme_sunset_dark_primary,
    onPrimary = md_theme_sunset_dark_onPrimary,
    primaryContainer = md_theme_sunset_dark_primaryContainer,
    onPrimaryContainer = md_theme_sunset_dark_onPrimaryContainer,
    secondary = md_theme_sunset_dark_secondary,
    onSecondary = md_theme_sunset_dark_onSecondary,
    secondaryContainer = md_theme_sunset_dark_secondaryContainer,
    onSecondaryContainer = md_theme_sunset_dark_onSecondaryContainer,
    tertiary = md_theme_sunset_dark_tertiary,
    onTertiary = md_theme_sunset_dark_onTertiary,
    tertiaryContainer = md_theme_sunset_dark_tertiaryContainer,
    onTertiaryContainer = md_theme_sunset_dark_onTertiaryContainer,
    error = md_theme_sunset_dark_error,
    onError = md_theme_sunset_dark_onError,
    errorContainer = md_theme_sunset_dark_errorContainer,
    onErrorContainer = md_theme_sunset_dark_onErrorContainer,
    background = md_theme_sunset_dark_background,
    onBackground = md_theme_sunset_dark_onBackground,
    surface = md_theme_sunset_dark_surface,
    onSurface = md_theme_sunset_dark_onSurface,
    surfaceVariant = md_theme_sunset_dark_surfaceVariant,
    onSurfaceVariant = md_theme_sunset_dark_onSurfaceVariant,
    outline = md_theme_sunset_dark_outline,
    outlineVariant = md_theme_sunset_dark_outlineVariant,
)

@Composable
fun PepinilloTheme(
    darkTheme: Boolean = isAppInDarkTheme(),
    dynamicColor: Boolean = true,
    selectedThemeId: String = "materialYou",
    isPro: Boolean = false,
    content: @Composable () -> Unit,
) {
    // Force default theme if not PRO
    val enforcedThemeId = if (isPro) selectedThemeId else "materialYou"
    val appTheme = AppTheme.named(enforcedThemeId)
    val useDynamicColor = dynamicColor && enforcedThemeId == "materialYou"

    // Sprint 8 (#494): each custom theme now owns a full ColorScheme so the whole UI follows it,
    // not only the focus-mode accents. MaterialYou keeps dynamic-color priority on API 31+.
    val colorScheme = when {
        useDynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        enforcedThemeId == "forest" -> if (darkTheme) ForestDarkColorScheme else ForestLightColorScheme
        enforcedThemeId == "ocean" -> if (darkTheme) OceanDarkColorScheme else OceanLightColorScheme
        enforcedThemeId == "sunset" -> if (darkTheme) SunsetDarkColorScheme else SunsetLightColorScheme
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    CompositionLocalProvider(LocalAppTheme provides appTheme) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            shapes = PepinilloShapes,
            content = content,
        )
    }
}
