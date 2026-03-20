package dev.creapolis.pepinillo.presentation

import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min

fun Color.toHsl(): Triple<Float, Float, Float> {
    val r = red
    val g = green
    val b = blue
    val cmax = max(r, max(g, b))
    val cmin = min(r, min(g, b))
    val l = (cmax + cmin) / 2f

    if (cmax == cmin) return Triple(0f, 0f, l)

    val d = cmax - cmin
    val s = if (l > 0.5f) d / (2f - cmax - cmin) else d / (cmax + cmin)
    val h = when (cmax) {
        r -> ((g - b) / d + (if (g < b) 6f else 0f)) * 60f
        g -> ((b - r) / d + 2f) * 60f
        else -> ((r - g) / d + 4f) * 60f
    }
    return Triple(h, s, l)
}

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

fun Color.shortBreakVariant(): Color {
    val (h, s, l) = toHsl()
    return hslToColor(
        h = (h + 30f) % 360f,
        s = s * 0.75f,
        l = min(l + 0.15f, 0.85f),
    )
}

fun Color.longBreakVariant(): Color {
    val (h, s, l) = toHsl()
    return hslToColor(
        h = (h + 50f) % 360f,
        s = s * 0.60f,
        l = min(l + 0.20f, 0.85f),
    )
}
