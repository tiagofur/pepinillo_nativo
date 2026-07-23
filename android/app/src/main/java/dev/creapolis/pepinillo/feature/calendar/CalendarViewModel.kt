package dev.creapolis.pepinillo.feature.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
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
    private val taskRepository: TaskRepository,
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

    val dayDetail: StateFlow<DayDetail?> = _selectedDate.flatMapLatest { dateMillis ->
        if (dateMillis == null) {
            flowOf(null)
        } else {
            val startOfDay = SessionRepository.startOfDay(dateMillis)
            val endOfDay = SessionRepository.addDays(startOfDay, 1)
            val dateFormat = SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.getDefault())

            combine(
                sessionRepository.getSessionsForDate(dateMillis),
                taskRepository.getTasksForDateFlow(startOfDay, endOfDay),
            ) { sessions, tasks ->
                val focusSessions = sessions.filter { it.phase == null || it.phase == "Work" }
                val totalMinutes = focusSessions.sumOf { (it.durationMillis / 60_000).toInt() }

                DayDetail(
                    dateLabel = dateFormat.format(dateMillis),
                    totalMinutes = totalMinutes,
                    sessionsCompleted = focusSessions.size,
                    taskCount = tasks.size,
                    sessions = focusSessions.map { s ->
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
                            isDue = t.dueDate != null && t.dueDate >= startOfDay && t.dueDate < endOfDay && !t.isCompleted,
                        )
                    },
                )
            }
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    fun previousMonth() {
        val cal = _displayedMonth.value.clone() as Calendar
        cal.add(Calendar.MONTH, -1)
        _displayedMonth.value = cal
        _selectedDate.value = null
    }

    fun nextMonth() {
        val cal = _displayedMonth.value.clone() as Calendar
        cal.add(Calendar.MONTH, 1)
        _displayedMonth.value = cal
        _selectedDate.value = null
    }

    fun selectDay(dateMillis: Long) {
        _selectedDate.value = dateMillis
    }
}
