package dev.creapolis.pepinillo.feature.dashboard

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.network.AIReportResponse
import dev.creapolis.pepinillo.core.network.ReportInsight
import dev.creapolis.pepinillo.data.local.dao.ProductivityReportDao
import dev.creapolis.pepinillo.data.local.entity.ProductivityReportEntity
import dev.creapolis.pepinillo.domain.report.ReportDataBuilder
import dev.creapolis.pepinillo.domain.report.ReportGenerator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.Calendar
import java.util.UUID
import javax.inject.Inject

data class AIReportUiState(
    val period: String = "week",
    val report: AIReportResponse? = null,
    val isGenerating: Boolean = false,
    @field:androidx.annotation.StringRes val errorRes: Int? = null,
    val creditsLeft: Int = 0,
)

private const val TAG = "AIReportVM"

@HiltViewModel
class AIReportViewModel @Inject constructor(
    private val reportDataBuilder: ReportDataBuilder,
    private val reportGenerator: ReportGenerator,
    private val reportDao: ProductivityReportDao,
    private val userRepository: dev.creapolis.pepinillo.data.repository.UserRepository,
) : ViewModel() {

    private val json = Json { ignoreUnknownKeys = true }

    private val _state = MutableStateFlow(AIReportUiState())
    val state: StateFlow<AIReportUiState> = _state.asStateFlow()

    init {
        loadCachedOrGenerate()
        observeUser()
    }

    private fun observeUser() {
        viewModelScope.launch {
            userRepository.observeCachedUser().collect { user ->
                if (user != null) {
                    _state.value = _state.value.copy(creditsLeft = user.aiCreditsBalance)
                }
            }
        }
    }

    fun setPeriod(period: String) {
        if (period == _state.value.period) return
        _state.value = AIReportUiState(period = period)
        loadCachedOrGenerate()
    }

    fun regenerate() {
        generateReport(forceRegenerate = true)
    }

    fun retry() {
        generateReport(forceRegenerate = false)
    }

    private fun loadCachedOrGenerate() {
        viewModelScope.launch {
            val periodStart = computePeriodStart(_state.value.period)
            val cached = reportDao.getReport(_state.value.period, periodStart)
            if (cached != null) {
                val response = try {
                    AIReportResponse(
                        title = cached.title,
                        highlights = json.decodeFromString<List<String>>(cached.highlights),
                        insights = json.decodeFromString<List<ReportInsight>>(cached.insights),
                        recommendations = json.decodeFromString<List<String>>(cached.recommendations),
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error decoding cached report", e)
                    null
                }
                if (response != null) {
                    _state.value = _state.value.copy(report = response)
                    return@launch
                }
            }
            generateReport(forceRegenerate = false)
        }
    }

    private fun generateReport(forceRegenerate: Boolean) {
        if (_state.value.isGenerating) return

        viewModelScope.launch {
            _state.value = _state.value.copy(isGenerating = true, errorRes = null)

            try {
                val payload = reportDataBuilder.buildPayload(_state.value.period)
                val response = reportGenerator.generate(payload)

                _state.value = _state.value.copy(
                    report = response,
                    isGenerating = false,
                    errorRes = null,
                )
                cacheReport(response)
                cleanupOldReports()
            } catch (e: Exception) {
                Log.e(TAG, "Error generating report", e)
                _state.value = _state.value.copy(
                    isGenerating = false,
                    errorRes = dev.creapolis.pepinillo.R.string.error_unknown,
                )
            }
        }
    }

    private suspend fun cacheReport(response: AIReportResponse) {
        try {
            val now = System.currentTimeMillis()
            val periodStart = computePeriodStart(_state.value.period)
            val entity = ProductivityReportEntity(
                id = UUID.randomUUID().toString(),
                period = _state.value.period,
                periodStart = periodStart,
                periodEnd = now,
                generatedAt = now,
                title = response.title,
                highlights = json.encodeToString(response.highlights),
                insights = json.encodeToString(response.insights),
                recommendations = json.encodeToString(response.recommendations),
            )
            reportDao.insertReport(entity)
        } catch (e: Exception) {
            Log.e(TAG, "Error caching report", e)
        }
    }

    private suspend fun cleanupOldReports() {
        try {
            val thirtyDaysAgo = System.currentTimeMillis() - 30L * 24 * 60 * 60 * 1000
            reportDao.deleteOldReports(thirtyDaysAgo)
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning old reports", e)
        }
    }

    private fun computePeriodStart(period: String): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        when (period) {
            "week" -> cal.add(Calendar.DAY_OF_YEAR, -7)
            "month" -> cal.add(Calendar.DAY_OF_YEAR, -30)
        }
        return cal.timeInMillis
    }
}
