package dev.creapolis.pepinillo.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import dev.creapolis.pepinillo.MainActivity

class DailyStatsWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                StatsContent(context)
            }
        }
    }
}

@Composable
private fun StatsContent(context: Context) {
    val minutes = WidgetStateManager.readMinutes(context)
    val sessions = WidgetStateManager.readSessions(context)
    val streak = WidgetStateManager.readStreak(context)
    val completedTasks = WidgetStateManager.readCompletedTasks(context)

    val hours = minutes / 60
    val mins = minutes % 60
    val timeText = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(24.dp)
            .padding(16.dp)
            .clickable(actionStartActivity<MainActivity>()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Hoy",
            style = TextStyle(
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = GlanceTheme.colors.primary,
            ),
        )

        Spacer(modifier = GlanceModifier.height(12.dp))

        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            StatBlock(value = timeText, label = "Enfoque", emoji = "\u23F1")
            Spacer(modifier = GlanceModifier.width(16.dp))
            StatBlock(value = "$sessions", label = "Sesiones", emoji = "\u2705")
            Spacer(modifier = GlanceModifier.width(16.dp))
            StatBlock(value = "$streak", label = "Racha", emoji = "\uD83D\uDD25")
            Spacer(modifier = GlanceModifier.width(16.dp))
            StatBlock(value = "$completedTasks", label = "Tareas", emoji = "\uD83D\uDCCB")
        }
    }
}

@Composable
private fun StatBlock(value: String, label: String, emoji: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = emoji,
            style = TextStyle(fontSize = 18.sp),
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = value,
            style = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 20.sp,
                color = GlanceTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            ),
        )
        Text(
            text = label,
            style = TextStyle(
                fontSize = 10.sp,
                color = GlanceTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            ),
        )
    }
}

class DailyStatsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyStatsWidget()
}
