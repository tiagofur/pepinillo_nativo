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
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.WidgetTaskStateManager
import dev.creapolis.pepinillo.service.FocusTimerService
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.just
import io.mockk.runs
import io.mockk.clearMocks
import io.mockk.verify
import org.junit.After
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
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

import androidx.lifecycle.viewModelScope

import android.os.SystemClock
import android.os.PowerManager
import io.mockk.mockkStatic
import io.mockk.unmockkStatic

import org.junit.BeforeClass
import org.junit.AfterClass

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

    companion object {
        private var currentTimeProvider: () -> Long = { 0L }

        @JvmStatic
        @BeforeClass
        fun beforeClass() {
            mockkStatic(SystemClock::class)
            every { SystemClock.elapsedRealtime() } answers { currentTimeProvider() }
        }

        @JvmStatic
        @AfterClass
        fun afterClass() {
            unmockkStatic(SystemClock::class)
        }
    }

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
        currentTimeProvider = { testScope.testScheduler.currentTime }

        mockkObject(WearDataLayerHelper)
        every { WearDataLayerHelper.pushTimer(any(), any(), any()) } just runs

        mockkObject(WidgetTaskStateManager)
        coEvery { WidgetTaskStateManager.updateLinkedTaskId(any(), any()) } just runs

        mockkObject(FocusTimerService)
        every { FocusTimerService.start(any()) } just runs
        every { FocusTimerService.stop(any()) } just runs

        val powerManager = mockk<PowerManager>(relaxed = true) {
            every { isIgnoringBatteryOptimizations(any()) } returns true
        }

        // Context stub -- service calls are no-ops
        context = mockk(relaxed = true) {
            every { getSystemService(Context.POWER_SERVICE) } returns powerManager
            every { packageName } returns "dev.creapolis.pepinillo"
        }

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
            coEvery { getTaskById(any()) } answers {
                val id = firstArg<String>()
                dev.creapolis.pepinillo.feature.tasks.model.Task(
                    id = id,
                    title = "Mock Task $id",
                    createdAt = 0L,
                    completedAt = null,
                    energyLevel = dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel.Regular,
                    estimatedPomodoros = 0,
                    completedPomodoros = 0,
                    priority = dev.creapolis.pepinillo.feature.tasks.model.TaskPriority.None,
                )
            }
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

    private fun TestScope.collectUiState() {
        backgroundScope.launch { viewModel.uiState.collect {} }
    }

    @After
    fun tearDown() {
        viewModel.viewModelScope.cancel()
        unmockkObject(WearDataLayerHelper)
        unmockkObject(WidgetTaskStateManager)
        unmockkObject(FocusTimerService)
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
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Flow)
        advanceUntilIdle()
        // Engine should NOT have changed mode (still the default Pomodoro)
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
        assertTrue(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Blocks without subscription shows paywall`() = runTest {
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Blocks)
        advanceUntilIdle()
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
        assertTrue(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Flow with subscription works`() = runTest {
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        viewModel.selectMode(FocusMode.Flow)
        advanceUntilIdle()
        assertEquals(FocusMode.Flow, engine.state.value.mode)
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with pro mode Blocks with subscription works`() = runTest {
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        viewModel.selectMode(FocusMode.Blocks)
        advanceUntilIdle()
        assertEquals(FocusMode.Blocks, engine.state.value.mode)
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `selectMode with monthly subscription allows all modes`() = runTest {
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        viewModel.selectMode(FocusMode.Flow)
        advanceUntilIdle()
        assertEquals(FocusMode.Flow, engine.state.value.mode)
        viewModel.selectMode(FocusMode.Blocks)
        advanceUntilIdle()
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
    fun `onStartStopClick when Idle and battery optimization active shows dialog`() = runTest {
        collectUiState()
        val powerManager = mockk<PowerManager>(relaxed = true) {
            every { isIgnoringBatteryOptimizations(any()) } returns false
        }
        val contextWithOptimization = mockk<Context>(relaxed = true) {
            every { getSystemService(Context.POWER_SERVICE) } returns powerManager
            every { packageName } returns "dev.creapolis.pepinillo"
        }
        val localViewModel = FocusViewModel(
            context = contextWithOptimization,
            focusEngine = engine,
            sessionRepository = sessionRepository,
            taskRepository = taskRepository,
            prefsRepo = prefsRepo,
            featureGate = featureGate,
            soundscapeManager = soundscapeManager,
        )
        backgroundScope.launch { localViewModel.uiState.collect {} }
        
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        assertFalse(localViewModel.uiState.value.showBatteryWarningDialog)
        
        localViewModel.onStartStopClick()
        advanceUntilIdle()
        
        assertTrue(localViewModel.uiState.value.showBatteryWarningDialog)
        assertEquals(TimerStatus.Idle, engine.state.value.status)
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
        collectUiState()
        viewModel.onStopClick()
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.showStopConfirmation)
    }

    @Test
    fun `confirmStop calls engine stop and hides confirmation`() = runTest {
        collectUiState()
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
        viewModel.confirmStop()
        advanceUntilIdle()
        // After stop the engine resets to Idle
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        assertFalse(viewModel.uiState.value.showStopConfirmation)
    }

    @Test
    fun `dismissStopConfirmation hides dialog without stopping`() = runTest {
        collectUiState()
        engine.start()
        viewModel.onStopClick()
        runCurrent()
        assertTrue(viewModel.uiState.value.showStopConfirmation)
        viewModel.dismissStopConfirmation()
        runCurrent()
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
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)
        viewModel.selectMode(FocusMode.Flow) // triggers paywall
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.showPaywall)
        viewModel.dismissPaywall()
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    @Test
    fun `dismissPaywall is safe to call when paywall not showing`() = runTest {
        collectUiState()
        assertFalse(viewModel.uiState.value.showPaywall)
        viewModel.dismissPaywall() // should not throw
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.showPaywall)
    }

    // #503: FocusScreen keys a LaunchedEffect on `showPaywall`, so the flag must be a
    // single rising edge that dismissPaywall clears. This pins the contract: a blocked
    // selectMode flips it true exactly once, dismiss flips it false, and re-selecting a
    // blocked mode re-arms it (so the effect re-fires).
    @Test
    fun `showPaywall is edge-triggered across blocked selections and dismiss`() = runTest {
        collectUiState()
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.FREE)

        assertFalse(viewModel.uiState.value.showPaywall)
        viewModel.selectMode(FocusMode.Flow)
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.showPaywall)

        viewModel.dismissPaywall()
        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.showPaywall)

        // Re-arming must work — the LaunchedEffect in FocusScreen re-fires on the next rising edge.
        viewModel.selectMode(FocusMode.Blocks)
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.showPaywall)
        viewModel.dismissPaywall()
        advanceUntilIdle()
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
        collectUiState()
        advanceUntilIdle()
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

    // -----------------------------------------------------------------------
    // A-C5: FGS lifecycle collector must dedupe on status transitions
    // -----------------------------------------------------------------------

    @Test
    fun `FGS start is called only on status transition not on every tick emission`() = runTest {
        // The init collector has already processed the initial Idle emission (stop called
        // once). Clear the baseline so verifies below count from this point onward.
        runCurrent()
        clearMocks(FocusTimerService)
        every { FocusTimerService.start(any()) } just runs
        every { FocusTimerService.stop(any()) } just runs

        // Idle -> Running: start exactly once
        engine.start()
        runCurrent()
        verify(exactly = 1) { FocusTimerService.start(context) }

        // Same-status re-emissions (linkedTaskId changes while Running) must NOT call start
        engine.linkTask("task-a")
        runCurrent()
        engine.linkTask("task-b")
        runCurrent()
        verify(exactly = 1) { FocusTimerService.start(context) }

        // Running -> Paused: no start/stop (Paused branch is a no-op)
        engine.pause()
        runCurrent()
        verify(exactly = 1) { FocusTimerService.start(context) }
        verify(exactly = 0) { FocusTimerService.stop(context) }

        // Paused -> Running: status transition -> start called again (total 2)
        engine.start()
        runCurrent()
        verify(exactly = 2) { FocusTimerService.start(context) }
    }

    // ───────────── Soundscape lifecycle: fade policy on WaitingForNext (#525) ─────────────
    //
    // The lifecycle collector calls soundscapeManager.fadeOut() on WaitingForNext when the timer
    // was previously Running/Paused (wasRunningOrPaused guard). fadeOut() is a safe no-op when
    // nothing is playing (SoundscapeManager checks mediaPlayer ?: return), so these tests verify
    // the branch logic without needing a real soundscape to be playing.
    //
    // We use setStatusForTesting(Running) instead of engine.start() to avoid launching the real
    // timer loop (which spins on the UnconfinedTestDispatcher and never completes).

    @Test
    fun `soundscape fades out when timer reaches WaitingForNext after running`() = runTest {
        // Running → sets wasRunningOrPaused = true on the collector's next emission.
        engine.setStatusForTesting(TimerStatus.Running)
        runCurrent()

        // Transition to WaitingForNext (phase complete, auto-start off) → must fade out (#525).
        engine.setStatusForTesting(TimerStatus.WaitingForNext)
        runCurrent()

        verify(exactly = 1) { soundscapeManager.fadeOut() }
    }

    @Test
    fun `soundscape continues playing during pause`() = runTest {
        engine.setStatusForTesting(TimerStatus.Running)
        runCurrent()

        // Paused → soundscape must keep playing (no fadeOut, no stop).
        engine.setStatusForTesting(TimerStatus.Paused)
        runCurrent()

        verify(exactly = 0) { soundscapeManager.fadeOut() }
        verify(exactly = 0) { soundscapeManager.stop() }
    }

    @Test
    fun `soundscape fades out when timer transitions to Idle`() = runTest {
        engine.setStatusForTesting(TimerStatus.Running)
        runCurrent()

        engine.setStatusForTesting(TimerStatus.Idle)
        runCurrent()

        verify(exactly = 1) { soundscapeManager.fadeOut() }
    }

    @Test
    fun `soundscape does not fade when transitioning to WaitingForNext without prior activity`() = runTest {
        // Cold start directly into WaitingForNext (e.g. restored state) with no Running history
        // → wasRunningOrPaused is false, so no fadeOut should fire.
        engine.setStatusForTesting(TimerStatus.WaitingForNext)
        runCurrent()

        verify(exactly = 0) { soundscapeManager.fadeOut() }
    }
}
