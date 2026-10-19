package dev.creapolis.pepinillo.feature.dashboard

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.dashboard.model.DashboardStats
import dev.creapolis.pepinillo.feature.dashboard.model.ReflectionPreviews
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TestWatcher
import org.junit.runner.Description

// ---------------------------------------------------------------------------
// MainDispatcherRule -- swaps Dispatchers.Main with a test dispatcher
// ---------------------------------------------------------------------------

@OptIn(ExperimentalCoroutinesApi::class)
class DashboardMainDispatcherRule(
    private val testDispatcher: kotlinx.coroutines.test.TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(testDispatcher)
    }

    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}

// ===========================================================================
//  Tests
// ===========================================================================

@OptIn(ExperimentalCoroutinesApi::class)
class DashboardViewModelTest {

    @get:Rule
    val mainDispatcherRule = DashboardMainDispatcherRule()

    private lateinit var testScope: TestScope
    private lateinit var subscriptionStateFlow: MutableStateFlow<SubscriptionState>

    // Shared flows — MutableStateFlow so we can update them before creating the ViewModel
    private val weekSessionsFlow = MutableStateFlow(emptyList<FocusSessionEntity>())
    private val monthSessionsFlow = MutableStateFlow(emptyList<FocusSessionEntity>())
    private val yearSessionsFlow = MutableStateFlow(emptyList<FocusSessionEntity>())
    private val previousWeekSessionsFlow = MutableStateFlow(emptyList<FocusSessionEntity>())
    private val previousMonthSessionsFlow = MutableStateFlow(emptyList<FocusSessionEntity>())

    // Mocks
    private lateinit var sessionRepository: SessionRepository
    private lateinit var taskRepository: TaskRepository
    private lateinit var featureGate: FeatureGate

    @Before
    fun setUp() {
        testScope = TestScope(UnconfinedTestDispatcher())

        // Subscription / FeatureGate -- default: FREE
        subscriptionStateFlow = MutableStateFlow(SubscriptionState(tier = SubscriptionTier.FREE))
        val subscriptionManager = mockk<SubscriptionManager> {
            every { subscriptionState } returns subscriptionStateFlow
        }
        featureGate = FeatureGate(subscriptionManager)

        // Session repository: flows backed by MutableStateFlow for dynamic updates
        sessionRepository = mockk(relaxed = true) {
            every { getTodayStats() } returns flowOf(null)
            every { getWeekStats() } returns flowOf(emptyList<DailyStatsEntity>())
            every { getMonthStats() } returns flowOf(emptyList<DailyStatsEntity>())
            every { getYearStats() } returns flowOf(emptyList<DailyStatsEntity>())
            every { getAllDaysWithSessions() } returns flowOf(emptyList<DailyStatsEntity>())
            every { getWeekSessions() } returns weekSessionsFlow
            every { getMonthSessions() } returns monthSessionsFlow
            every { getYearSessions() } returns yearSessionsFlow
            every { getPreviousWeekSessions() } returns previousWeekSessionsFlow
            every { getPreviousMonthSessions() } returns previousMonthSessionsFlow
            every { calculateBestStreak(any()) } returns 0
        }

        // Task repository
        taskRepository = mockk(relaxed = true) {
            coEvery { getTaskTitle(any()) } returns "Mock Task"
        }
    }

    /**
     * Create a ViewModel with current flow states. Must be called AFTER setting
     * the desired flow values (weekSessionsFlow, etc.).
     */
    private fun createViewModel(): DashboardViewModel = DashboardViewModel(
        sessionRepository = sessionRepository,
        taskRepository = taskRepository,
        featureGate = featureGate,
    )

    private fun TestScope.collectStats(vm: DashboardViewModel) {
        backgroundScope.launch { vm.stats.collect {} }
    }

    private fun TestScope.collectWeeklyReport(vm: DashboardViewModel) {
        backgroundScope.launch { vm.weeklyReport.collect {} }
    }

    private fun TestScope.collectMonthlyReport(vm: DashboardViewModel) {
        backgroundScope.launch { vm.monthlyReport.collect {} }
    }

    private fun TestScope.collectReflectionPreviews(vm: DashboardViewModel) {
        backgroundScope.launch { vm.reflectionPreviews.collect {} }
    }

    private fun TestScope.collectIsRefreshing(vm: DashboardViewModel) {
        backgroundScope.launch { vm.isRefreshing.collect {} }
    }

    // Helper to create a work session
    private fun workSession(
        wasCompleted: Boolean = true,
        durationMinutes: Int = 25,
        startTime: Long = System.currentTimeMillis(),
    ) = FocusSessionEntity(
        mode = "Pomodoro",
        startTime = startTime,
        endTime = startTime + durationMinutes * 60_000L,
        durationMillis = durationMinutes * 60_000L,
        phase = "Work",
        wasCompleted = wasCompleted,
    )

    // -----------------------------------------------------------------------
    // completionRate tests
    // -----------------------------------------------------------------------

    @Test
    fun `completionRate is computed correctly when sessions exist`() = runTest {
        // 3 sessions: 2 completed, 1 not → 2/3 = 0.6667, rounded to 2 decimals = 0.67
        weekSessionsFlow.value = listOf(
            workSession(wasCompleted = true),
            workSession(wasCompleted = true),
            workSession(wasCompleted = false),
        )
        yearSessionsFlow.value = weekSessionsFlow.value

        val vm = createViewModel()
        collectStats(vm)
        advanceUntilIdle()

        val stats = vm.stats.value
        assertEquals(0.67, stats.completionRate, 0.001)
    }

    @Test
    fun `completionRate is 0 when no sessions exist`() = runTest {
        val vm = createViewModel()
        collectStats(vm)
        advanceUntilIdle()

        val stats = vm.stats.value
        assertEquals(0.0, stats.completionRate, 0.001)
    }

    @Test
    fun `completionRate is 1 when all sessions completed`() = runTest {
        weekSessionsFlow.value = listOf(
            workSession(wasCompleted = true),
            workSession(wasCompleted = true),
            workSession(wasCompleted = true),
        )
        yearSessionsFlow.value = weekSessionsFlow.value

        val vm = createViewModel()
        collectStats(vm)
        advanceUntilIdle()

        val stats = vm.stats.value
        assertEquals(1.0, stats.completionRate, 0.001)
    }

    // -----------------------------------------------------------------------
    // focusScore denominator (calendar days of the period, not days with rows)
    // -----------------------------------------------------------------------

    @Test
    fun `focusScore divides by calendar days of the period so rest days are not free points`() = runTest {
        // 2 active days of a 7-day week, 210 minutes each:
        // consistency = 2/7 (not 2/2 = 1.0), avg = 420/7 = 60 -> minuteScore = 1.
        // score = floor(2f/7 * 60 + 40) = 57. Old denominator (days with rows) gave 100.
        val today = SessionRepository.startOfDay(System.currentTimeMillis())
        val yesterday = SessionRepository.addDays(today, -1)
        val rows = listOf(
            DailyStatsEntity(date = today, totalMinutes = 210, sessionsCompleted = 3),
            DailyStatsEntity(date = yesterday, totalMinutes = 210, sessionsCompleted = 3),
        )
        every { sessionRepository.getWeekStats() } returns flowOf(rows)

        val vm = createViewModel()
        collectStats(vm)
        advanceUntilIdle()

        assertEquals(57, vm.stats.value.focusScore)
    }

    // -----------------------------------------------------------------------
    // reflectionPreviews tests
    // -----------------------------------------------------------------------

    @Test
    fun `reflectionPreviews emits correct weekly data`() = runTest {
        weekSessionsFlow.value = listOf(
            workSession(durationMinutes = 30, startTime = 1000L),
            workSession(durationMinutes = 20, startTime = 2000L),
        )

        val vm = createViewModel()
        collectWeeklyReport(vm)
        collectReflectionPreviews(vm)
        advanceUntilIdle()

        val previews = vm.reflectionPreviews.value
        assertEquals(50, previews.weeklyMinutes)
        assertEquals(2, previews.weeklySessions)
    }

    @Test
    fun `reflectionPreviews emits correct monthly data`() = runTest {
        monthSessionsFlow.value = listOf(
            workSession(durationMinutes = 45, startTime = 1000L),
            workSession(durationMinutes = 15, startTime = 2000L),
            workSession(durationMinutes = 30, startTime = 3000L),
        )

        val vm = createViewModel()
        collectMonthlyReport(vm)
        collectReflectionPreviews(vm)
        advanceUntilIdle()

        val previews = vm.reflectionPreviews.value
        assertEquals(90, previews.monthlyMinutes)
        assertEquals(3, previews.monthlySessions)
    }

    @Test
    fun `reflectionPreviews defaults to zeros when no report data`() = runTest {
        val vm = createViewModel()
        collectWeeklyReport(vm)
        collectMonthlyReport(vm)
        collectReflectionPreviews(vm)
        advanceUntilIdle()

        val previews = vm.reflectionPreviews.value
        assertEquals(0, previews.weeklyMinutes)
        assertEquals(0, previews.weeklySessions)
        assertEquals(0, previews.monthlyMinutes)
        assertEquals(0, previews.monthlySessions)
    }

    // -----------------------------------------------------------------------
    // refresh / isRefreshing tests
    // -----------------------------------------------------------------------

    @Test
    fun `isRefreshing is false initially`() = runTest {
        val vm = createViewModel()
        collectIsRefreshing(vm)
        advanceUntilIdle()

        assertEquals(false, vm.isRefreshing.value)
    }

    @Test
    fun `refresh sets isRefreshing to true then false`() = runTest {
        val vm = createViewModel()
        val states = mutableListOf<Boolean>()
        val job = backgroundScope.launch { vm.isRefreshing.collect { states.add(it) } }
        advanceUntilIdle()

        vm.refresh()
        advanceUntilIdle()

        // Should have been true during refresh
        assertTrue(states.contains(true))
        // And back to false after refresh completes
        assertEquals(false, vm.isRefreshing.value)
        job.cancel()
    }
}
