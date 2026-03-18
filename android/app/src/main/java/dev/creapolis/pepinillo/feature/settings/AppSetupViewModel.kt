package dev.creapolis.pepinillo.feature.settings

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.util.ManufacturerUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

data class AppSetupUiState(
    val notificationsGranted: Boolean = true,
    val batteryOptimizationExcluded: Boolean = false,
    val exactAlarmsAllowed: Boolean = true,
    val showExactAlarmsRow: Boolean = false,
    val autoStartAcknowledged: Boolean = false,
    val showAutoStartRow: Boolean = false,
    val manufacturerName: String = "",
    val grantedCount: Int = 0,
    val totalCount: Int = 0,
    val allConfigured: Boolean = false,
)

@HiltViewModel
class AppSetupViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AppSetupUiState())
    val uiState: StateFlow<AppSetupUiState> = _uiState.asStateFlow()

    private val prefs = context.getSharedPreferences("app_setup", Context.MODE_PRIVATE)

    init {
        refreshPermissions()
    }

    fun refreshPermissions() {
        val notificationsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else true

        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val batteryExcluded = pm.isIgnoringBatteryOptimizations(context.packageName)

        val showExactAlarms = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val exactAlarmsAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.canScheduleExactAlarms()
        } else true

        val showAutoStart = ManufacturerUtils.hasKnownAutoStartSettings()
        val autoStartAcknowledged = prefs.getBoolean("autostart_acknowledged", false)
        val manufacturerName = ManufacturerUtils.getManufacturerDisplayName()

        // Count granted vs total
        var granted = 0
        var total = 0

        total++
        if (notificationsGranted) granted++

        total++
        if (batteryExcluded) granted++

        if (showExactAlarms) {
            total++
            if (exactAlarmsAllowed) granted++
        }

        if (showAutoStart) {
            total++
            if (autoStartAcknowledged) granted++
        }

        _uiState.value = AppSetupUiState(
            notificationsGranted = notificationsGranted,
            batteryOptimizationExcluded = batteryExcluded,
            exactAlarmsAllowed = exactAlarmsAllowed,
            showExactAlarmsRow = showExactAlarms,
            autoStartAcknowledged = autoStartAcknowledged,
            showAutoStartRow = showAutoStart,
            manufacturerName = manufacturerName,
            grantedCount = granted,
            totalCount = total,
            allConfigured = granted == total,
        )
    }

    fun markAutoStartAcknowledged() {
        prefs.edit().putBoolean("autostart_acknowledged", true).apply()
        refreshPermissions()
    }
}
