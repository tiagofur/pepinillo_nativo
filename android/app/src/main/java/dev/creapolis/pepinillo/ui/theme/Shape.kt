package dev.creapolis.pepinillo.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/**
 * App-wide shape tokens. Centralizes corner radii so components don't hand-pick
 * inconsistent values (previously 12/16/20/22/24dp scattered across screens).
 *
 * Mapping guidance:
 * - small  (8dp)  : chips, small controls, text-field corners
 * - medium (16dp) : cards, list rows, bottom-sheet contents
 * - large  (24dp) : hero cards, sheets
 * - extraLarge (28dp): streak hero, dialog-like surfaces
 */
val PepinilloShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(28.dp),
)
