package dev.creapolis.pepinillo.ui.components

import android.os.Build
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun GlassBox(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    tint: Color? = null,
    tintOpacity: Float = 0.08f,
    content: @Composable () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    val shape = RoundedCornerShape(cornerRadius)
    
    // Default tint: use primary dynamic color from Material Theme
    val systemTint = MaterialTheme.colorScheme.primary
    val resolvedTint = tint ?: systemTint
    val resolvedOpacity = if (tint != null) tintOpacity else 0.06f // subtle for system tint
    
    val baseBackgroundColor = if (isDark) {
        Color(0x1A121212)
    } else {
        Color(0x66FFFFFF)
    }

    Box(modifier = modifier) {
        // Background layer with blur (Android 12+)
        Box(
            modifier = Modifier
                .matchParentSize()
                .clip(shape)
                .then(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        Modifier.blur(25.dp)
                    } else {
                        Modifier
                    }
                )
                .background(baseBackgroundColor)
                .background(resolvedTint.copy(alpha = resolvedOpacity))
        )
        
        // Specular highlight border & glare sheen layer
        Box(
            modifier = Modifier
                .drawWithCache {
                    val isDarkTheme = isDark
                    onDrawWithContent {
                        drawContent()
                        
                        // Specular Border Highlight (White gradient reflecting light source)
                        val highlightBrush = Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = if (isDarkTheme) 0.16f else 0.28f),
                                Color.White.copy(alpha = if (isDarkTheme) 0.05f else 0.10f),
                                Color.Transparent,
                                Color.White.copy(alpha = if (isDarkTheme) 0.02f else 0.06f),
                                Color.White.copy(alpha = if (isDarkTheme) 0.10f else 0.20f)
                            )
                        )
                        drawRoundRect(
                            brush = highlightBrush,
                            cornerRadius = androidx.compose.ui.geometry.CornerRadius(cornerRadius.toPx(), cornerRadius.toPx()),
                            style = Stroke(width = 1.dp.toPx())
                        )
                        
                        // Glare Sheen Fill (Subtle reflection from top-left)
                        val glareBrush = Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = if (isDarkTheme) 0.02f else 0.04f),
                                Color.Transparent,
                                Color.Transparent
                            )
                        )
                        drawRoundRect(
                            brush = glareBrush,
                            cornerRadius = androidx.compose.ui.geometry.CornerRadius(cornerRadius.toPx(), cornerRadius.toPx())
                        )
                    }
                }
        ) {
            content()
        }
    }
}
