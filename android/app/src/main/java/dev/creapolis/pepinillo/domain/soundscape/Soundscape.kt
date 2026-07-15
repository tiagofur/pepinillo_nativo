package dev.creapolis.pepinillo.domain.soundscape

import androidx.annotation.RawRes
import androidx.annotation.StringRes
import dev.creapolis.pepinillo.R

enum class Soundscape(
    @param:StringRes val displayNameRes: Int,
    val emoji: String,
    @param:RawRes val rawResId: Int,
    val requiresPro: Boolean,
) {
    RAIN(R.string.soundscape_rain, "\uD83C\uDF27\uFE0F", R.raw.rain, false),
    FOREST(R.string.soundscape_forest, "\uD83C\uDF32", R.raw.forest, false),
    CAFE(R.string.soundscape_cafe, "\u2615", R.raw.cafe, false),
    WHITE_NOISE(R.string.soundscape_white_noise, "\uD83D\uDCFB", R.raw.white_noise, false),
    OCEAN(R.string.soundscape_ocean, "\uD83C\uDF0A", R.raw.ocean, true),
    FIREPLACE(R.string.soundscape_fireplace, "\uD83D\uDD25", R.raw.fireplace, true),
    BINAURAL(R.string.soundscape_binaural, "\uD83E\uDDE0", R.raw.binaural, true),
    LOFI(R.string.soundscape_lofi, "\uD83C\uDFB5", R.raw.lofi, true),
    ;

    companion object {
        val free: List<Soundscape> = entries.filter { !it.requiresPro }
        val pro: List<Soundscape> = entries.filter { it.requiresPro }
    }
}
