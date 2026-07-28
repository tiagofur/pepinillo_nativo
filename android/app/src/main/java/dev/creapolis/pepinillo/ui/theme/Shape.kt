package dev.creapolis.pepinillo.ui.theme

import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * App-wide shape tokens. Centralizes corner radii so components don't hand-pick
 * inconsistent values (previously 12/16/20/22/24dp scattered across screens).
 *
 * Two complementary layers coexist:
 *
 * 1. [PepinilloShapes] — the five Material 3 `Shapes` slots, used by components that read
 *    `MaterialTheme.shapes.*` automatically (M3 `Card`, `Button`, `TextField`, …) and by
 *    call sites that only need a generic "small/medium/large" radius.
 *
 * 2. [PepinilloShapeTokens] — semantic, named roles for the radii the app actually uses.
 *    The Judgment Day audit (#511 / JD-11) found ~130 hardcoded `RoundedCornerShape`
 *    call sites, with 20dp (cards/surfaces) and 12dp (buttons/fields) dominating but
 *    mapping to *no* M3 slot. Named tokens preserve the exact visual value while giving
 *    each occurrence a single source of truth. Prefer these over raw radii.
 *
 * Mapping guidance (M3 slots):
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

/**
 * Semantic shape tokens — the single source of truth for every corner radius in the app.
 *
 * Each value is pinned to the radius the app shipped before #511, so swapping a hardcoded
 * `RoundedCornerShape(20.dp)` for [card] is a pure refactor with zero visual change. New
 * surfaces should reach for the closest semantic role rather than inventing a new radius.
 *
 * Hairline progress-bar radii (2/3/4dp) and the animated Focus timer button morph
 * (30↔36dp) are intentionally **not** tokenized: they are not part of the design shape
 * language.
 */
object PepinilloShapeTokens {
    /** Cards, surfaces, sheets, stat tiles, plan/list containers (was 20dp). */
    val card: Shape = RoundedCornerShape(20.dp)

    /** Filled / outlined / text buttons and CTAs (was 12dp). */
    val button: Shape = RoundedCornerShape(12.dp)

    /** `OutlinedTextField` and other inputs (was 12dp). */
    val textField: Shape = RoundedCornerShape(12.dp)

    /** Small badges, icon containers, tag pills (was 8dp). */
    val badge: Shape = RoundedCornerShape(8.dp)

    /** Fully-rounded pills and metadata chips (was `RoundedCornerShape(999.dp)`). */
    val pill: Shape = CircleShape
}
