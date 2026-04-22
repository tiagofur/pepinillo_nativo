package dev.creapolis.pepinillo.feature.focus

import android.content.Context
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.soundscape.SoundscapeManager
import dev.creapolis.pepinillo.platform.feedback.FeedbackManager
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
class MainDispatcherRule(
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
class FocusViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var testScope: TestScope
    private lateinit var engine: FocusEngine
    private lateinit var subscriptionStateFlow: MutableStateFlow<SubscriptionState>
    private lateinit var viewModel: FocusViewModel

    // MockK mocks
    private lateinit var context: Context
    private lateinit var sessionRepository: SessionRepository
    private lateinit var taskRepository: TaskRepository
    private lateinit var prefsRepo: UserPreferencesRepository
    private lateinit var feedbackManager: FeedbackManager
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var featureGate: FeatureGate
    private lateinit var soundscapeManager: SoundscapeManager

    private val prefsFlow = MutableStateFlow(UserPreferences())

    @Before
    fun setUp() {
        testScope = TestScope(UnconfinedTestDispatcher())

        // Context stub -- service calls are no-ops
        context = mockk(relaxed = true)

        // Preferences
        prefsRepo = mockk {
            every { preferences } returns prefsFlow
        }

        // Session repository: flows for combine in uiState
        sessionRepository = mockk(relaxed = true) {
            every { getTodaySessionCount() } returns flowOf(0)
            every { getAllDaysWithSessions() } returns flowOf(emptyList())
            every { calculateCurrentStreak(any()) } returns 0
        }

        // Task repository
        taskRepository = mockk(relaxed = true) {
            every { getActiveTasks() } returns flowOf(emptyList())
            coEvery { getTaskById(any()) } returns null
        }

        // Feedback manager
        feedbackManager = mockk(relaxed = true)

        // Soundscape manager
        soundscapeManager = mockk(relaxed = true)

        // Subscription / FeatureGate -- default: FREE
        subscriptionStateFlow = MutableStateFlow(SubscriptionState(tier = SubscriptionTier.FREE))
        subscriptionManager = mockk {
            every { subscriptionState } returns subscriptionStateFlow
        }
        featureGate = FeatureGate(subscriptionManager)

        // Real FocusEngine backed by mocks
        engine = FocusEngine(
            sessionRepository = sessionRepository,
            taskRepository = taskRepository,
            prefsRepo = prefsRepo,
            feedbackManager = feedbackManager,
            scope = testScope,
        )

        // ViewModel under test
        viewModel = FocusViewModel(
            context = context,
            focusEngine = engine,
            sessionRepository = sessionRepository,
            taskRepository = taskRepository,
            prefsRepo = prefsRepo,
            featureGate = featureGate,
            soundscapeManager = soundscapeManager,
        )
    }

    // -----------------------------------------------------------------------
    // selectMode -- free tier modes
    // -----------------------------------------------------------------------

    @Test
    fun `selectMode with free mode Pomodoro works`() = runTest {
        viewModel.selectMode(FocusMode.Pomodoro)
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
    }

    @Test
    fun `selectMode with free mode Chrono works`() = runTest {
        viewModel.selectMode(FocusMode.Chrono)
        assertEquals(FocusMode.Chrono, engine.state.value.mode)
    }

    // -----------------------------------------------------------------------
    // selectMode -- pro modes without subscription -> paywall
    // -----------------------------------------------------------------------

    @Test
    fun `selectMode with pro mode Flow without subscription shows paywall`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Flow)
        // Engine should NOT have changed mode (still the default Pomodoro)
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
        assertTrue(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Blocks without subscription shows paywall`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Blocks)
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
        assertTrue(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Flow with subscription works`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        viewModel.selectMode(FocusMode.Flow)
        assertEquals(FocusMode.Flow, engine.state.value.mode)
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Blocks with subscription works`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        viewModel.selectMode(FocusMode.Blocks)
        assertEquals(FocusMode.Blocks, engine.state.value.mode)
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with lifetime subscription allows all modes`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_LIFETIME)
        viewModel.selectMode(FocusMode.Flow)
        assertEquals(FocusMode.Flow, engine.state.value.mode)
        viewModel.selectMode(FocusMode.Blocks)
        assertEquals(FocusMode.Blocks, engine.state.value.mode)
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    // -----------------------------------------------------------------------
    // onStartStopClick
    // -----------------------------------------------------------------------

    @Test
    fun `onStartStopClick when Idle starts engine`() = runTest {
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        viewModel.onStartStopClick()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `onStartStopClick when Running pauses engine`() = runTest {
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
        viewModel.onStartStopClick()
        assertEquals(TimerStatus.Paused, engine.state.value.status)
    }

    @Test
    fun `onStartStopClick when Paused resumes engine`() = runTest {
        engine.start()
        engine.pause()
        assertEquals(TimerStatus.Paused, engine.state.value.status)
        viewModel.onStartStopClick()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `onStartStopClick when WaitingForNext starts engine`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = 0L,
            totalMillis = 5 * 60 * 1000L,
            completedSessions = 1,
            sessionStartTime = 0L,
            status = TimerStatus.WaitingForNext,
        )
        testScope.advanceUntilIdle()
        assertEquals(TimerStatus.WaitingForNext, engine.state.value.status)
        viewModel.onStartStopClick()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    // -----------------------------------------------------------------------
    // onStopClick / confirmStop / dismissStopConfirmation
    // -----------------------------------------------------------------------

    @Test
    fun `onStopClick shows confirmation`() = runTest {
        viewModel.onStopClick()
        assertTrue(viewModel.uiState.value.showStopConfirmation)
    }

    @Test
    fun `confirmStop calls engine stop and hides confirmation`() = runTest {
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
        viewModel.confirmStop()
        testScope.advanceUntilIdle()
        // After stop the engine resets to Idle
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        assertFalse(viewModel.uiState.value.showStopConfirmation)
    }

    @Test
    fun `dismissStopConfirmation hides dialog without stopping`() = runTest {
        engine.start()
        viewModel.onStopClick()
        assertTrue(viewModel.uiState.value.showStopConfirmation)
        viewModel.dismissStopConfirmation()
        assertFalse(viewModel.uiState.value.showStopConfirmation)
        // Engine is still running
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    // -----------------------------------------------------------------------
    // linkTask
    // -----------------------------------------------------------------------

    @Test
    fun `linkTask updates engine linked task id`() = runTest {
        viewModel.linkTask("task-123")
        assertEquals("task-123", engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask with null clears linked task`() = runTest {
        viewModel.linkTask("task-123")
        viewModel.linkTask(null)
        assertNull(engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask hides task picker`() = runTest {
        viewModel.onTaskLinkClick()
        assertTrue(viewModel.showTaskPicker.value)
        viewModel.linkTask("task-abc")
        assertFalse(viewModel.showTaskPicker.value)
    }

    // -----------------------------------------------------------------------
    // dismissPaywall
    // -----------------------------------------------------------------------

    @Test
    fun `dismissPaywall hides paywall`() = runTest {
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Flow) // triggers paywall
        assertTrue(viewModel.uiState.value.showPaywall)
        viewModel.dismissPaywall()
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `dismissPaywall is safe to call when paywall not showing`() = runTest {
        assertFalse(viewModel.uiState.value.showPaywall)
        viewModel.dismissPaywall() // should not throw
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    // -----------------------------------------------------------------------
    // Task picker
    // -----------------------------------------------------------------------

    @Test
    fun `onTaskLinkClick shows task picker`() = runTest {
        viewModel.onTaskLinkClick()
        assertTrue(viewModel.showTaskPicker.value)
    }

    @Test
    fun `dismissTaskPicker hides task picker`() = runTest {
        viewModel.onTaskLinkClick()
        viewModel.dismissTaskPicker()
        assertFalse(viewModel.showTaskPicker.value)
    }

    // -----------------------------------------------------------------------
    // uiState defaults
    // -----------------------------------------------------------------------

    @Test
    fun `initial uiState has sensible defaults`() = runTest {
        val state = viewModel.uiState.value
        assertEquals(FocusMode.Pomodoro, state.selectedMode)
        assertFalse(state.isRunning)
        assertFalse(state.isPaused)
        assertFalse(state.showStopConfirmation)
        assertFalse(state.showPaywall)
        assertFalse(state.showTaskPicker)
        assertEquals(0, state.sessionsToday)
        assertEquals(0, state.currentStreak)
        assertFalse(state.keepScreenOn)
        assertFalse(state.breakSuggested)
        assertFalse(state.isWaitingForNext)
    }
}
