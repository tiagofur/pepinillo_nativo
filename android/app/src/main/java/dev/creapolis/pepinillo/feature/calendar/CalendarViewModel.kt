package dev.creapolis.pepinillo.feature.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import javax.inject.Inject

data class DayDetail(
    val dateLabel: String,
    val totalMinutes: Int,
    val sessionsCompleted: Int,
    val taskCount: Int,
    val sessions: List<SessionSummary>,
    val tasks: List<TaskSummary>,
)

data class SessionSummary(
    val mode: String,
    val startTime: Long,
    val durationMinutes: Int,
)

data class TaskSummary(
    val title: String,
    val isCompleted: Boolean,
    val isDue: Boolean,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val taskDao: TaskDao,
) : ViewModel() {

    private val _displayedMonth = MutableStateFlow(Calendar.getInstance())
    val displayedMonth: StateFlow<Calendar> = _displayedMonth.asStateFlow()

    private val _selectedDate = MutableStateFlow<Long?>(null)
    val selectedDate: StateFlow<Long?> = _selectedDate.asStateFlow()

    val activityDays: StateFlow<Set<Long>> = _displayedMonth.flatMapLatest { cal ->
        val year = cal.get(Calendar.YEAR)
        val month = cal.get(Calendar.MONTH)
        sessionRepository.getStatsForMonth(year, month).map { stats ->
            stats.filter { it.sessionsCompleted > 0 }.map { it.date }.toSet()
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptySet())

    private val _dayDetail = MutableStateFlow<DayDetail?>(null)
    val dayDetail: StateFlow<DayDetail?> = _dayDetail.asStateFlow()

    fun previousMonth() {
        val cal = _displayedMonth.value.clone() as Calendar
        cal.add(Calendar.MONTH, -1)
        _displayedMonth.value = cal
        _selectedDate.value = null
        _dayDetail.value = null
    }

    fun nextMonth() {
        val cal = _displayedMonth.value.clone() as Calendar
        cal.add(Calendar.MONTH, 1)
        _displayedMonth.value = cal
        _selectedDate.value = null
        _dayDetail.value = null
    }

    fun selectDay(dateMillis: Long) {
        _selectedDate.value = dateMillis
        viewModelScope.launch {
            loadDayDetail(dateMillis)
        }
    }

    private suspend fun loadDayDetail(dateMillis: Long) {
        val endOfDay = dateMillis + 24 * 60 * 60 * 1000
        val dateFormat = SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.getDefault())

        // Collect sessions for this day
        val sessions = mutableListOf<FocusSessionEntity>()
        sessionRepository.getSessionsForDate(dateMillis).collect { list ->
            sessions.clear()
            sessions.addAll(list)

            val tasks = try {
                taskDao.getTasksForDate(dateMillis, endOfDay)
            } catch (_: Exception) {
                emptyList()
            }

            val totalMinutes = sessions.sumOf { (it.durationMillis / 60_000).toInt() }

            _dayDetail.value = DayDetail(
                dateLabel = dateFormat.format(dateMillis),
                totalMinutes = totalMinutes,
                sessionsCompleted = sessions.size,
                taskCount = tasks.size,
                sessions = sessions.map { s ->
                    SessionSummary(
                        mode = s.mode,
                        startTime = s.startTime,
                        durationMinutes = (s.durationMillis / 60_000).toInt(),
                    )
                },
                tasks = tasks.map { t ->
                    TaskSummary(
                        title = t.title,
                        isCompleted = t.isCompleted,
                        isDue = t.dueDate != null && t.dueDate >= dateMillis && t.dueDate < endOfDay && !t.isCompleted,
                    )
                },
            )
            return@collect
        }
    }
}
