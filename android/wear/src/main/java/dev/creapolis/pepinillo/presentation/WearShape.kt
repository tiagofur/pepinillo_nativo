package dev.creapolis.pepinillo.presentation

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp

/**
 * Wear OS shape tokens — the single source of truth for corner radii in the wear module.
 *
 * The wear module cannot depend on `:app` (where the phone `PepinilloShapeTokens` live), so
 * this object mirrors the same semantic-role approach with the two radii the wear UI actually
 * uses. Keeping them centralized here means a future design tweak changes one value instead
 * of hunting across screens. Values match what the wear UI shipped before #511 — zero visual
 * change.
 */
object WearShapeTokens {
    /** Mode buttons and list-item buttons (was 12dp). */
    val button: Shape = RoundedCornerShape(12.dp)

    /** Voice/mode-picker action buttons (was 20dp). */
    val card: Shape = RoundedCornerShape(20.dp)
}
