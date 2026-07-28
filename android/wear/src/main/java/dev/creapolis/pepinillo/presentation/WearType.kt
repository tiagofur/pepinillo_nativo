package dev.creapolis.pepinillo.presentation

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.googlefonts.Font
import androidx.compose.ui.text.googlefonts.GoogleFont
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.Typography
import dev.creapolis.pepinillo.R

/**
 * Wear OS brand typography — mirrors the phone app's Montserrat family so the brand reads
 * consistently phone ↔ Wear (#516).
 *
 * The wear module cannot depend on `:app`, so this file duplicates the GoogleFonts provider +
 * Montserrat family definition locally. The family registers the five weights the wearable UI
 * actually renders (Light, Normal, Medium, SemiBold, Bold); without explicit per-weight entries
 * the `FontWeight` calls in the screens (`Light` on the timer numeral, `Bold`/`Medium` on
 * labels) silently fall back to the regular cut.
 *
 * Only the slots the wear screens use (labelSmall/Medium, bodyMedium, titleMedium) and the
 * timer-hero displayLarge carry Montserrat; the rest keep the Wear M3 defaults to avoid
 * unnecessary font downloads on a constrained device. System fallback is automatic when
 * Google Fonts is unavailable.
 */

private val provider = GoogleFont.Provider(
    providerAuthority = "com.google.android.gms.fonts",
    providerPackage = "com.google.android.gms",
    certificates = R.array.com_google_android_gms_fonts_certs,
)

private val MontserratFont = GoogleFont("Montserrat")

private val MontserratFontFamily = FontFamily(
    Font(googleFont = MontserratFont, fontProvider = provider, weight = FontWeight.Light),
    Font(googleFont = MontserratFont, fontProvider = provider, weight = FontWeight.Normal),
    Font(googleFont = MontserratFont, fontProvider = provider, weight = FontWeight.Medium),
    Font(googleFont = MontserratFont, fontProvider = provider, weight = FontWeight.SemiBold),
    Font(googleFont = MontserratFont, fontProvider = provider, weight = FontWeight.Bold),
)

val WearTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = MontserratFontFamily,
        fontWeight = FontWeight.Light,
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp,
    ),
    titleMedium = TextStyle(
        fontFamily = MontserratFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.15.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = MontserratFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = MontserratFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = MontserratFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp,
    ),
)
