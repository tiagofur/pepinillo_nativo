package dev.creapolis.pepinillo.ui.theme

import androidx.compose.ui.graphics.Color
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import kotlin.math.max
import kotlin.math.min

/**
 * Converts a Compose Color to HSL (Hue 0-360, Saturation 0-1, Lightness 0-1).
 */
fun Color.toHsl(): Triple<Float, Float, Float> {
    val r = red
    val g = green
    val b = blue
    val max = max(r, max(g, b))
    val min = min(r, min(g, b))
    val l = (max + min) / 2f

    if (max == min) return Triple(0f, 0f, l)

    val d = max - min
    val s = if (l > 0.5f) d / (2f - max - min) else d / (max + min)
    val h = when (max) {
        r -> ((g - b) / d + (if (g < b) 6f else 0f)) * 60f
        g -> ((b - r) / d + 2f) * 60f
        else -> ((r - g) / d + 4f) * 60f
    }
    return Triple(h, s, l)
}

/**
 * Creates a Color from HSL values.
 */
fun hslToColor(h: Float, s: Float, l: Float): Color {
    if (s == 0f) return Color(l, l, l)

    val q = if (l < 0.5f) l * (1f + s) else l + s - l * s
    val p = 2f * l - q

    fun hueToRgb(t: Float): Float {
        val tt = when {
            t < 0f -> t + 1f
            t > 1f -> t - 1f
            else -> t
        }
        return when {
            tt < 1f / 6f -> p + (q - p) * 6f * tt
            tt < 1f / 2f -> q
            tt < 2f / 3f -> p + (q - p) * (2f / 3f - tt) * 6f
            else -> p
        }
    }

    val hNorm = h / 360f
    return Color(
        red = hueToRgb(hNorm + 1f / 3f),
        green = hueToRgb(hNorm),
        blue = hueToRgb(hNorm - 1f / 3f),
    )
}

/**
 * Derives a calmer, break-appropriate color from a focus accent color.
 * Short breaks shift hue +30° toward teal, reduce saturation, increase lightness.
 * Long breaks shift more aggressively for a deeper rest feel.
 */
fun Color.breakVariant(phase: FocusPhase): Color {
    if (phase == FocusPhase.Work) return this
    val (h, s, l) = toHsl()
    return when (phase) {
        FocusPhase.ShortBreak -> hslToColor(
            h = (h + 30f) % 360f,
            s = s * 0.75f,
            l = min(l + 0.15f, 0.85f),
        )
        FocusPhase.LongBreak -> hslToColor(
            h = (h + 50f) % 360f,
            s = s * 0.60f,
            l = min(l + 0.20f, 0.85f),
        )
        else -> this
    }
}

/**
 * Calculates WCAG 2.1 relative luminance for a Compose Color (sRGB)
 * and returns high-contrast content color (Color.Black or Color.White) for on-accent labels.
 */
fun Color.onAccentColor(): Color {
    fun componentLuminance(c: Float): Float {
        return if (c <= 0.04045f) c / 12.92f else Math.pow(((c + 0.055) / 1.055), 2.4).toFloat()
    }
    val r = componentLuminance(red)
    val g = componentLuminance(green)
    val b = componentLuminance(blue)
    val luminance = 0.2126f * r + 0.7152f * g + 0.0722f * b
    return if (luminance > 0.45f) Color.Black else Color.White
}

