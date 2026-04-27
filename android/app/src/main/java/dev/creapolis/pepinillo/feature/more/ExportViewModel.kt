package dev.creapolis.pepinillo.feature.more

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

enum class ExportDateRange(val label: String) {
    LAST_7_DAYS("Last 7 Days"),
    LAST_30_DAYS("Last 30 Days"),
    LAST_90_DAYS("Last 90 Days"),
    ALL_TIME("All Time"),
}

data class ExportUiState(
    val isPro: Boolean = false,
    val dateRange: ExportDateRange = ExportDateRange.LAST_30_DAYS,
    val includeSessions: Boolean = true,
    val includeTasks: Boolean = true,
    val isExporting: Boolean = false,
    val exportSuccess: Boolean? = null,
    val errorMessage: String? = null,
)

@HiltViewModel
class ExportViewModel @Inject constructor(
    private val focusSessionDao: FocusSessionDao,
    private val taskDao: TaskDao,
    private val featureGate: FeatureGate,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ExportUiState(isPro = featureGate.isPro))
    val uiState: StateFlow<ExportUiState> = _uiState.asStateFlow()

    fun setDateRange(range: ExportDateRange) {
        _uiState.update { it.copy(dateRange = range) }
    }

    fun setIncludeSessions(include: Boolean) {
        _uiState.update { it.copy(includeSessions = include) }
    }

    fun setIncludeTasks(include: Boolean) {
        _uiState.update { it.copy(includeTasks = include) }
    }

    fun clearResult() {
        _uiState.update { it.copy(exportSuccess = null, errorMessage = null) }
    }

    fun triggerExport(context: Context) {
        val state = _uiState.value
        if (!state.includeSessions && !state.includeTasks) return

        _uiState.update { it.copy(isExporting = true, exportSuccess = null, errorMessage = null) }

        viewModelScope.launch {
            runCatching {
                val csv = buildCsv(state)
                val file = writeCsvToCache(context, csv)
                shareFile(context, file)
                _uiState.update { it.copy(isExporting = false, exportSuccess = true) }
            }.onFailure { e ->
                _uiState.update {
                    it.copy(
                        isExporting = false,
                        exportSuccess = false,
                        errorMessage = e.localizedMessage ?: "Export failed",
                    )
                }
            }
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private suspend fun buildCsv(state: ExportUiState): String = withContext(Dispatchers.IO) {
        val sb = StringBuilder()
        val (startTime, endTime) = dateRangeToEpoch(state.dateRange)

        if (state.includeSessions) {
            val sessions = if (state.dateRange == ExportDateRange.ALL_TIME) {
                focusSessionDao.getAllSessionsSync()
            } else {
                focusSessionDao.getSessionsInRangeSync(startTime, endTime)
            }

            sb.appendLine("# Focus Sessions")
            sb.appendLine("id,mode,phase,startTime,endTime,durationSeconds,wasCompleted,pomodoroNumber,interruptions")
            sessions.forEach { s ->
                val start = formatEpoch(s.startTime)
                val end = formatEpoch(s.endTime)
                val durationSec = s.durationMillis / 1000
                sb.appendLine(
                    "${s.id},${s.mode},${s.phase ?: ""},${start},${end}," +
                        "${durationSec},${s.wasCompleted},${s.pomodoroNumber ?: ""},${s.interruptions}",
                )
            }
            sb.appendLine()
        }

        if (state.includeTasks) {
            val tasks = taskDao.getAllTasksSync()
            val filtered = if (state.dateRange == ExportDateRange.ALL_TIME) tasks
            else tasks.filter { it.createdAt in startTime..endTime }

            sb.appendLine("# Tasks")
            sb.appendLine("id,title,isCompleted,energyLevel,dueDate,createdAt")
            filtered.forEach { t ->
                val due = t.dueDate?.let { formatEpoch(it) } ?: ""
                val created = formatEpoch(t.createdAt)
                val safeTitle = t.title.replace(",", ";").replace("\n", " ")
                sb.appendLine("${t.id},\"${safeTitle}\",${t.isCompleted},${t.energyLevel},${due},${created}")
            }
        }

        sb.toString()
    }

    private fun writeCsvToCache(context: Context, csv: String): File {
        val dir = File(context.cacheDir, "exports").also { it.mkdirs() }
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val file = File(dir, "pepinillo_export_$timestamp.csv")
        file.writeText(csv, Charsets.UTF_8)
        return file
    }

    private fun shareFile(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/csv"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Pepinillo Export")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Share Export").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    private fun dateRangeToEpoch(range: ExportDateRange): Pair<Long, Long> {
        val now = System.currentTimeMillis()
        val daysMs = when (range) {
            ExportDateRange.LAST_7_DAYS -> 7L * 24 * 60 * 60 * 1000
            ExportDateRange.LAST_30_DAYS -> 30L * 24 * 60 * 60 * 1000
            ExportDateRange.LAST_90_DAYS -> 90L * 24 * 60 * 60 * 1000
            ExportDateRange.ALL_TIME -> 0L
        }
        return Pair(now - daysMs, now)
    }

    private fun formatEpoch(epochMs: Long): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(epochMs))
}
