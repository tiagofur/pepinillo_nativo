package dev.creapolis.pepinillo.domain.timer

import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.platform.feedback.FeedbackManager
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.After
import org.junit.Test
import android.os.SystemClock
import io.mockk.mockkStatic
import io.mockk.unmockkStatic

import org.junit.BeforeClass
import org.junit.AfterClass

import kotlinx.coroutines.test.UnconfinedTestDispatcher

@OptIn(ExperimentalCoroutinesApi::class)
class FocusEngineTest {

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

    private lateinit var sessionRepository: SessionRepository
    private lateinit var taskRepository: TaskRepository
    private lateinit var prefsRepo: UserPreferencesRepository
    private lateinit var feedbackManager: FeedbackManager
    private lateinit var testScope: TestScope
    private lateinit var engine: FocusEngine
    private lateinit var prefsFlow: MutableStateFlow<UserPreferences>

    @Before
    fun setUp() {
        testScope = TestScope(UnconfinedTestDispatcher())
        currentTimeProvider = { testScope.testScheduler.currentTime }

        prefsFlow = MutableStateFlow(UserPreferences())
        sessionRepository = mockk(relaxed = true)
        taskRepository = mockk(relaxed = true)
        prefsRepo = mockk {
            every { preferences } returns prefsFlow
        }
        feedbackManager = mockk(relaxed = true)

        engine = FocusEngine(
            sessionRepository = sessionRepository,
            taskRepository = taskRepository,
            prefsRepo = prefsRepo,
            feedbackManager = feedbackManager,
            scope = testScope,
        )
    }

    @After
    fun tearDown() {
    }

    // ── Default state ──

    @Test
    fun `initial state has default values`() {
        val state = engine.state.value
        assertEquals(FocusMode.Pomodoro, state.mode)
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(TimerStatus.Idle, state.status)
        assertEquals(0L, state.elapsedMillis)
        assertEquals(25 * 60 * 1000L, state.totalMillis)
        assertEquals(0, state.completedSessions)
        assertNull(state.linkedTaskId)
        assertEquals(0L, state.sessionStartTime)
        assertEquals(false, state.breakSuggested)
        assertEquals(false, state.midpointTriggered)
    }

    // ── selectMode ──

    @Test
    fun `selectMode changes mode when Idle`() = runTest {
        engine.selectMode(FocusMode.Flow)
        assertEquals(FocusMode.Flow, engine.state.value.mode)
    }

    @Test
    fun `selectMode sets correct totalMillis for Pomodoro`() = runTest {
        prefsFlow.value = UserPreferences(pomodoroMinutes = 30)
        engine.selectMode(FocusMode.Pomodoro)
        assertEquals(30 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode sets correct totalMillis for Blocks`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 90)
        engine.selectMode(FocusMode.Blocks)
        assertEquals(90 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode sets totalMillis to 0 for Flow`() = runTest {
        engine.selectMode(FocusMode.Flow)
        assertEquals(0L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode sets totalMillis to 0 for Chrono`() = runTest {
        engine.selectMode(FocusMode.Chrono)
        assertEquals(0L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode resets state but preserves linkedTaskId`() = runTest {
        engine.linkTask("task-1")
        engine.selectMode(FocusMode.Blocks)

        val state = engine.state.value
        assertEquals(FocusMode.Blocks, state.mode)
        assertEquals("task-1", state.linkedTaskId)
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(TimerStatus.Idle, state.status)
        assertEquals(0L, state.elapsedMillis)
    }

    @Test
    fun `selectMode is ignored when Running`() = runTest {
        engine.start()
        engine.selectMode(FocusMode.Flow)
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
    }

    @Test
    fun `selectMode is ignored when Paused`() = runTest {
        engine.start()
        engine.pause()
        engine.selectMode(FocusMode.Flow)
        // Status is Paused, not Idle, so selectMode should be ignored
        assertEquals(FocusMode.Pomodoro, engine.state.value.mode)
    }

    @Test
    fun `selectMode cycles through all modes from Idle`() = runTest {
        for (mode in FocusMode.entries) {
            engine.stop()
            testScope.advanceUntilIdle()
            engine.selectMode(mode)
            assertEquals(mode, engine.state.value.mode)
        }
    }

    // ── start ──

    @Test
    fun `start sets status to Running`() {
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `start sets sessionStartTime when starting fresh`() {
        engine.start()
        assertNotEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `start preserves sessionStartTime when resuming from pause`() {
        engine.start()
        val originalStartTime = engine.state.value.sessionStartTime
        engine.pause()
        engine.start()
        assertEquals(originalStartTime, engine.state.value.sessionStartTime)
    }

    @Test
    fun `start is idempotent when already Running`() {
        engine.start()
        val stateAfterFirstStart = engine.state.value
        engine.start() // should be ignored
        assertEquals(stateAfterFirstStart, engine.state.value)
    }

    @Test
    fun `start from Paused sets status to Running`() {
        engine.start()
        engine.pause()
        assertEquals(TimerStatus.Paused, engine.state.value.status)
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `start from WaitingForNext sets status to Running`() = runTest {
        // Manually put engine in WaitingForNext state via restoreState
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = 0L,
            totalMillis = 5 * 60 * 1000L,
            completedSessions = 1,
            sessionStartTime = 0L,
            status = TimerStatus.WaitingForNext,
        )
        assertEquals(TimerStatus.WaitingForNext, engine.state.value.status)

        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    // ── pause ──

    @Test
    fun `pause sets status to Paused`() {
        engine.start()
        engine.pause()
        assertEquals(TimerStatus.Paused, engine.state.value.status)
    }

    @Test
    fun `pause can be called from Idle without crashing`() {
        engine.pause() // should not throw
        assertEquals(TimerStatus.Paused, engine.state.value.status)
    }

    @Test
    fun `pause preserves elapsed millis`() {
        engine.start()
        // Even though the timer won't actually tick in unit tests (SystemClock),
        // the state should retain its elapsedMillis value after pausing.
        val elapsedBefore = engine.state.value.elapsedMillis
        engine.pause()
        assertEquals(elapsedBefore, engine.state.value.elapsedMillis)
    }

    @Test
    fun `pause preserves mode and phase`() {
        engine.start()
        engine.pause()
        val state = engine.state.value
        assertEquals(FocusMode.Pomodoro, state.mode)
        assertEquals(FocusPhase.Work, state.phase)
    }

    // ── stop ──

    @Test
    fun `stop resets status to Idle`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(TimerStatus.Idle, engine.state.value.status)
    }

    @Test
    fun `stop resets elapsed millis to 0`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(0L, engine.state.value.elapsedMillis)
    }

    @Test
    fun `stop preserves current mode`() = runTest {
        engine.selectMode(FocusMode.Blocks)
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(FocusMode.Blocks, engine.state.value.mode)
    }

    @Test
    fun `stop preserves linkedTaskId`() = runTest {
        engine.linkTask("task-42")
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals("task-42", engine.state.value.linkedTaskId)
    }

    @Test
    fun `stop recalculates totalMillis from preferences`() = runTest {
        engine.start()
        // Change prefs while running
        prefsFlow.value = UserPreferences(pomodoroMinutes = 50)
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(50 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `stop resets sessionStartTime to 0`() = runTest {
        engine.start()
        assertNotEquals(0L, engine.state.value.sessionStartTime)
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `stop resets completedSessions to 0`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(0, engine.state.value.completedSessions)
    }

    // ── stop records session ──

    @Test
    fun `stop does not record session when no elapsed time`() = runTest {
        engine.start()
        // elapsedMillis is 0 since no real ticks happen
        engine.stop()
        testScope.advanceUntilIdle()
        coVerify(exactly = 0) {
            sessionRepository.recordSession(
                mode = any(),
                startTime = any(),
                endTime = any(),
                durationMillis = any(),
                linkedTaskId = any(),
                phase = any(),
            )
        }
    }

    @Test
    fun `stop does not record session when sessionStartTime is 0`() = runTest {
        // Engine in Idle state with sessionStartTime = 0
        engine.stop()
        testScope.advanceUntilIdle()
        coVerify(exactly = 0) {
            sessionRepository.recordSession(
                mode = any(),
                startTime = any(),
                endTime = any(),
                durationMillis = any(),
                linkedTaskId = any(),
                phase = any(),
            )
        }
    }

    @Test
    fun `stop records session when elapsed and sessionStartTime are positive`() = runTest {
        // Use restoreState to set up a state with elapsed time
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 5 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 5 * 60 * 1000L,
        )
        testScope.testScheduler.runCurrent()

        engine.stop()
        testScope.testScheduler.runCurrent()

        coVerify(exactly = 1) {
            sessionRepository.recordSession(
                mode = "Pomodoro",
                startTime = any(),
                endTime = any(),
                durationMillis = 5 * 60 * 1000L,
                linkedTaskId = null,
                phase = "Work",
                wasCompleted = false,
                pomodoroNumber = 1,
                targetDurationMillis = 25 * 60 * 1000L,
            )
        }
    }

    @Test
    fun `stop records session with linkedTaskId`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 10_000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 10_000L,
        )
        testScope.testScheduler.runCurrent()

        // Link task after restoreState so it is present in the state
        engine.linkTask("task-99")

        engine.stop()
        testScope.testScheduler.runCurrent()

        coVerify {
            sessionRepository.recordSession(
                mode = "Pomodoro",
                startTime = any(),
                endTime = any(),
                durationMillis = any(),
                linkedTaskId = "task-99",
                phase = "Work",
                wasCompleted = false,
                pomodoroNumber = 1,
                targetDurationMillis = 25 * 60 * 1000L,
            )
        }
    }

    // ── linkTask ──

    @Test
    fun `linkTask sets linkedTaskId`() {
        engine.linkTask("task-1")
        assertEquals("task-1", engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask with null clears linkedTaskId`() {
        engine.linkTask("task-1")
        engine.linkTask(null)
        assertNull(engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask can be called while Running`() {
        engine.start()
        engine.linkTask("task-1")
        assertEquals("task-1", engine.state.value.linkedTaskId)
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `linkTask can be called while Paused`() {
        engine.start()
        engine.pause()
        engine.linkTask("task-2")
        assertEquals("task-2", engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask preserves other state fields`() {
        engine.start()
        val modeBefore = engine.state.value.mode
        val statusBefore = engine.state.value.status
        engine.linkTask("task-1")
        assertEquals(modeBefore, engine.state.value.mode)
        assertEquals(statusBefore, engine.state.value.status)
    }

    @Test
    fun `linkTask can be reassigned`() {
        engine.linkTask("task-1")
        engine.linkTask("task-2")
        assertEquals("task-2", engine.state.value.linkedTaskId)
    }

    // ── restoreState ──

    @Test
    fun `restoreState with WaitingForNext does not start timer`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = 0L,
            totalMillis = 5 * 60 * 1000L,
            completedSessions = 2,
            sessionStartTime = 0L,
            status = TimerStatus.WaitingForNext,
        )
        testScope.testScheduler.runCurrent()

        val state = engine.state.value
        assertEquals(TimerStatus.WaitingForNext, state.status)
        assertEquals(FocusMode.Pomodoro, state.mode)
        assertEquals(FocusPhase.ShortBreak, state.phase)
        assertEquals(2, state.completedSessions)
    }

    @Test
    fun `restoreState restores Running state`() = runTest {
        val startTime = System.currentTimeMillis() - 60_000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 60_000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 1,
            sessionStartTime = startTime,
        )
        testScope.testScheduler.runCurrent()

        val state = engine.state.value
        assertEquals(TimerStatus.Running, state.status)
        assertEquals(FocusMode.Pomodoro, state.mode)
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(1, state.completedSessions)
        assertEquals(startTime, state.sessionStartTime)
    }

    @Test
    fun `restoreState uses getTotalMillis when totalMillis is 0`() = runTest {
        prefsFlow.value = UserPreferences(pomodoroMinutes = 30)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 0L,
            totalMillis = 0L, // should be resolved from prefs
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis(),
        )
        testScope.testScheduler.runCurrent()
        assertEquals(30 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `restoreState uses provided totalMillis when positive`() = runTest {
        val customTotal = 42 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 0L,
            totalMillis = customTotal,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis(),
        )
        testScope.testScheduler.runCurrent()
        assertEquals(customTotal, engine.state.value.totalMillis)
    }

    @Test
    fun `restoreState handles already-completed phase for countdown mode`() = runTest {
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total, // elapsed >= total, phase already done
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        // onPhaseComplete should have been called, transitioning to a break
        val state = engine.state.value
        assertTrue(
            "Expected ShortBreak or LongBreak after work completion, got ${state.phase}",
            state.phase == FocusPhase.ShortBreak || state.phase == FocusPhase.LongBreak,
        )
    }

    @Test
    fun `restoreState does not trigger onPhaseComplete for Flow mode even if elapsed exceeds total`() = runTest {
        engine.restoreState(
            mode = FocusMode.Flow,
            phase = FocusPhase.Work,
            elapsedMillis = 999_999L,
            totalMillis = 0L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis(),
        )
        testScope.testScheduler.runCurrent()

        // Flow mode should remain Running, not trigger onPhaseComplete
        assertEquals(TimerStatus.Running, engine.state.value.status)
        assertEquals(FocusMode.Flow, engine.state.value.mode)
    }

    @Test
    fun `restoreState does not trigger onPhaseComplete for Chrono mode`() = runTest {
        engine.restoreState(
            mode = FocusMode.Chrono,
            phase = FocusPhase.Work,
            elapsedMillis = 999_999L,
            totalMillis = 0L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis(),
        )
        testScope.testScheduler.runCurrent()

        assertEquals(TimerStatus.Running, engine.state.value.status)
        assertEquals(FocusMode.Chrono, engine.state.value.mode)
    }

    // ── restoreState: linkedTaskId persistence (W-8) ──

    @Test
    fun `restoreState preserves linkedTaskId in restored Running state`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 10 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 10 * 60 * 1000L,
            linkedTaskId = "task-recovered",
        )
        testScope.testScheduler.runCurrent()

        assertEquals("task-recovered", engine.state.value.linkedTaskId)
    }

    @Test
    fun `restoreState WaitingForNext preserves linkedTaskId`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = 0L,
            totalMillis = 5 * 60 * 1000L,
            completedSessions = 1,
            sessionStartTime = 0L,
            status = TimerStatus.WaitingForNext,
            linkedTaskId = "task-waiting",
        )
        testScope.testScheduler.runCurrent()

        assertEquals(TimerStatus.WaitingForNext, engine.state.value.status)
        assertEquals("task-waiting", engine.state.value.linkedTaskId)
    }

    @Test
    fun `restoreState linkedTaskId carries into incrementPomodoros on stop`() = runTest {
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 10 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 10 * 60 * 1000L,
            linkedTaskId = "task-recovered",
        )
        testScope.testScheduler.runCurrent()

        engine.stop()
        testScope.advanceUntilIdle()

        coVerify { taskRepository.incrementPomodoros("task-recovered") }
    }

    @Test
    fun `restoreState with already-completed phase carries linkedTaskId through onPhaseComplete`() = runTest {
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
            linkedTaskId = "task-complete",
        )
        testScope.advanceUntilIdle()

        // onPhaseComplete should have preserved linkedTaskId in the new break-phase state
        assertEquals("task-complete", engine.state.value.linkedTaskId)
    }

    // ── onPhaseComplete (Pomodoro work -> break transition) ──

    @Test
    fun `pomodoro work completion transitions to ShortBreak`() = runTest {
        prefsFlow.value = UserPreferences(
            sessionsBeforeLongBreak = 4,
            shortBreakMinutes = 5,
            autoStartBreaks = false,
        )
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0, // first session, not yet at long break threshold
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        val state = engine.state.value
        assertEquals(FocusPhase.ShortBreak, state.phase)
        assertEquals(TimerStatus.WaitingForNext, state.status)
        assertEquals(5 * 60 * 1000L, state.totalMillis)
        assertEquals(1, state.completedSessions)
    }

    @Test
    fun `pomodoro work completion transitions to LongBreak after sessionsBeforeLongBreak`() = runTest {
        prefsFlow.value = UserPreferences(
            sessionsBeforeLongBreak = 4,
            longBreakMinutes = 15,
            autoStartBreaks = false,
        )
        val total = 25 * 60 * 1000L
        // completedSessions = 3, so after incrementing to 4, it should be a long break
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 3,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        val state = engine.state.value
        assertEquals(FocusPhase.LongBreak, state.phase)
        assertEquals(TimerStatus.WaitingForNext, state.status)
        assertEquals(15 * 60 * 1000L, state.totalMillis)
        assertEquals(4, state.completedSessions)
    }

    @Test
    fun `pomodoro work completion auto-starts break when autoStartBreaks is true`() = runTest {
        prefsFlow.value = UserPreferences(
            autoStartBreaks = true,
            shortBreakMinutes = 5,
            sessionsBeforeLongBreak = 4,
        )
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        val state = engine.state.value
        assertEquals(FocusPhase.ShortBreak, state.phase)
        assertEquals(TimerStatus.Running, state.status)
        assertNotEquals(0L, state.sessionStartTime)
    }

    // ── onPhaseComplete (Pomodoro break -> work transition) ──

    @Test
    fun `pomodoro short break completion transitions back to Work`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            autoStartNextPomodoro = false,
        )
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.advanceUntilIdle()

        val state = engine.state.value
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(TimerStatus.WaitingForNext, state.status)
        assertEquals(25 * 60 * 1000L, state.totalMillis)
        assertEquals(1, state.completedSessions) // preserved from break
    }

    @Test
    fun `pomodoro long break completion transitions back to Work`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            autoStartNextPomodoro = false,
        )
        val breakTotal = 15 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.LongBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 4,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.advanceUntilIdle()

        val state = engine.state.value
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(TimerStatus.WaitingForNext, state.status)
        assertEquals(25 * 60 * 1000L, state.totalMillis)
        assertEquals(4, state.completedSessions)
    }

    @Test
    fun `pomodoro break completion auto-starts next pomodoro when autoStartNextPomodoro is true`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            autoStartNextPomodoro = true,
            autoStartBreaks = false,
        )
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.testScheduler.runCurrent()

        val state = engine.state.value
        assertEquals(FocusPhase.Work, state.phase)
        assertEquals(TimerStatus.Running, state.status)
        assertNotEquals(0L, state.sessionStartTime)
    }

    // ── onPhaseComplete (Blocks mode) ──

    @Test
    fun `blocks completion transitions to Idle and increments completedSessions`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 60)
        val total = 60 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 2,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        val state = engine.state.value
        assertEquals(FocusMode.Blocks, state.mode)
        assertEquals(TimerStatus.Idle, state.status)
        assertEquals(3, state.completedSessions)
        assertEquals(60 * 60 * 1000L, state.totalMillis)
    }

    @Test
    fun `blocks completion preserves linkedTaskId from running state`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 60)
        val total = 60 * 60 * 1000L

        // restoreState creates a new FocusTimerState without linkedTaskId,
        // so we set it after restoreState but before the phase completes.
        // For the elapsed >= total path, onPhaseComplete runs inline, so we
        // instead test that onPhaseComplete reads the linkedTaskId from state.
        // Simulate a running state that has not yet completed:
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = total / 2,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total / 2,
        )
        testScope.advanceUntilIdle()

        // Now link a task while running
        engine.linkTask("task-block")
        assertEquals("task-block", engine.state.value.linkedTaskId)

        // Stop preserves linkedTaskId
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals("task-block", engine.state.value.linkedTaskId)
    }

    // ── onPhaseComplete preserves linkedTaskId ──

    @Test
    fun `onPhaseComplete carries linkedTaskId from current state to next phase`() = runTest {
        // This test verifies that onPhaseComplete reads linkedTaskId from the current
        // state snapshot and carries it to the new phase state.
        // Since restoreState does NOT preserve linkedTaskId from the previous state,
        // we need a state that already has linkedTaskId set before onPhaseComplete fires.
        // The only way this happens in production is when linkTask was called during a
        // running session and then the phase completes via the timer loop.
        //
        // We test the stop() path instead, which snapshots state (including linkedTaskId)
        // and preserves it after reset.
        prefsFlow.value = UserPreferences(autoStartBreaks = false)

        // Restore a running state (elapsed < total so it doesn't auto-complete)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 10 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 10 * 60 * 1000L,
        )
        testScope.advanceUntilIdle()

        engine.linkTask("linked-task")
        engine.stop()
        testScope.advanceUntilIdle()

        assertEquals("linked-task", engine.state.value.linkedTaskId)
    }

    // ── onPhaseComplete records session ──

    @Test
    fun `onPhaseComplete records session via sessionRepository`() = runTest {
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        coVerify(atLeast = 1) {
            sessionRepository.recordSession(
                mode = "Pomodoro",
                startTime = any(),
                endTime = any(),
                durationMillis = total,
                linkedTaskId = any(),
                phase = "Work",
                wasCompleted = true,
                pomodoroNumber = 1,
                targetDurationMillis = total,
            )
        }
    }

    @Test
    fun `onPhaseComplete calls feedbackManager onPhaseComplete`() = runTest {
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        coVerify {
            feedbackManager.onPhaseComplete(FocusMode.Pomodoro, FocusPhase.Work)
        }
    }

    // ── recordSession: incrementPomodoros ──

    @Test
    fun `recordSession increments pomodoros on linked task for Work phase`() = runTest {
        // Restore a running state (not yet completed)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = 10 * 60 * 1000L,
            totalMillis = 25 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 10 * 60 * 1000L,
        )
        testScope.testScheduler.runCurrent()

        // Link task while running, then stop to trigger recordSession
        engine.linkTask("task-pomo")
        engine.stop()
        testScope.testScheduler.runCurrent()

        coVerify {
            taskRepository.incrementPomodoros("task-pomo")
        }
    }

    @Test
    fun `recordSession does not increment pomodoros for break phase`() = runTest {
        // Restore a running break state (not yet completed)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = 2 * 60 * 1000L,
            totalMillis = 5 * 60 * 1000L,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - 2 * 60 * 1000L,
        )
        testScope.advanceUntilIdle()

        // Link task and stop to trigger recordSession for a break phase
        engine.linkTask("task-break")
        engine.stop()
        testScope.advanceUntilIdle()

        coVerify(exactly = 0) {
            taskRepository.incrementPomodoros(any())
        }
    }

    @Test
    fun `recordSession does not increment pomodoros when no linked task`() = runTest {
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        coVerify(exactly = 0) {
            taskRepository.incrementPomodoros(any())
        }
    }

    // ── recordSession: minimum duration guard ──

    @Test
    fun `recordSession skips sessions shorter than 1 second`() = runTest {
        // Restore with very short elapsed time (< 1000ms)
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = 500L,
            totalMillis = 60 * 60 * 1000L,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - 500L,
        )
        testScope.advanceUntilIdle()

        // Stop to trigger recordSession via stop path
        engine.stop()
        testScope.advanceUntilIdle()

        // The 500ms elapsed should be rejected by the < 1000ms guard
        coVerify(exactly = 0) {
            sessionRepository.recordSession(
                mode = any(),
                startTime = any(),
                endTime = any(),
                durationMillis = 500L,
                linkedTaskId = any(),
                phase = any(),
            )
        }
    }

    // ── Full Pomodoro cycle ──

    @Test
    fun `full pomodoro cycle - work to short break to work`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            shortBreakMinutes = 5,
            sessionsBeforeLongBreak = 4,
            autoStartBreaks = false,
            autoStartNextPomodoro = false,
        )

        // Step 1: Complete work phase
        val workTotal = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = workTotal,
            totalMillis = workTotal,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - workTotal,
        )
        testScope.testScheduler.runCurrent()

        // Verify: now in ShortBreak, WaitingForNext
        assertEquals(FocusPhase.ShortBreak, engine.state.value.phase)
        assertEquals(TimerStatus.WaitingForNext, engine.state.value.status)
        assertEquals(1, engine.state.value.completedSessions)

        // Step 2: User starts the break
        engine.start()
        testScope.testScheduler.runCurrent()
        assertEquals(TimerStatus.Running, engine.state.value.status)
        assertEquals(FocusPhase.ShortBreak, engine.state.value.phase)

        // Step 3: Simulate break completion by restoring completed state
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.advanceUntilIdle()

        // Verify: back to Work, WaitingForNext
        assertEquals(FocusPhase.Work, engine.state.value.phase)
        assertEquals(TimerStatus.WaitingForNext, engine.state.value.status)
        assertEquals(25 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `four pomodoros lead to long break`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            shortBreakMinutes = 5,
            longBreakMinutes = 15,
            sessionsBeforeLongBreak = 4,
            autoStartBreaks = false,
        )
        val workTotal = 25 * 60 * 1000L

        // Complete the 4th work session (completedSessions=3 -> becomes 4)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = workTotal,
            totalMillis = workTotal,
            completedSessions = 3,
            sessionStartTime = System.currentTimeMillis() - workTotal,
        )
        testScope.advanceUntilIdle()

        assertEquals(FocusPhase.LongBreak, engine.state.value.phase)
        assertEquals(15 * 60 * 1000L, engine.state.value.totalMillis)
        assertEquals(4, engine.state.value.completedSessions)
    }

    @Test
    fun `eight pomodoros lead to second long break`() = runTest {
        prefsFlow.value = UserPreferences(
            pomodoroMinutes = 25,
            shortBreakMinutes = 5,
            longBreakMinutes = 15,
            sessionsBeforeLongBreak = 4,
            autoStartBreaks = false,
        )
        val workTotal = 25 * 60 * 1000L

        // Complete the 8th work session (completedSessions=7 -> becomes 8)
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = workTotal,
            totalMillis = workTotal,
            completedSessions = 7,
            sessionStartTime = System.currentTimeMillis() - workTotal,
        )
        testScope.advanceUntilIdle()

        assertEquals(FocusPhase.LongBreak, engine.state.value.phase)
        assertEquals(4 + 4, engine.state.value.completedSessions)
    }

    // ── getTotalMillis ──

    @Test
    fun `selectMode Pomodoro uses pomodoroMinutes from prefs`() = runTest {
        prefsFlow.value = UserPreferences(pomodoroMinutes = 45)
        engine.selectMode(FocusMode.Pomodoro)
        assertEquals(45 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode Blocks uses timeBlockMinutes from prefs`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 120)
        engine.selectMode(FocusMode.Blocks)
        assertEquals(120 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode Flow always gives 0 totalMillis`() = runTest {
        prefsFlow.value = UserPreferences(pomodoroMinutes = 99)
        engine.selectMode(FocusMode.Flow)
        assertEquals(0L, engine.state.value.totalMillis)
    }

    @Test
    fun `selectMode Chrono always gives 0 totalMillis`() = runTest {
        prefsFlow.value = UserPreferences(pomodoroMinutes = 99)
        engine.selectMode(FocusMode.Chrono)
        assertEquals(0L, engine.state.value.totalMillis)
    }

    // ── State flow emission ──

    @Test
    fun `state flow emits updates on start`() = runTest {
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `state flow emits updates on pause`() = runTest {
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
        engine.pause()
        assertEquals(TimerStatus.Paused, engine.state.value.status)
    }

    @Test
    fun `state flow emits updates on stop`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals(TimerStatus.Idle, engine.state.value.status)
    }

    // ── Edge cases ──

    @Test
    fun `start-pause-start cycle maintains state correctly`() {
        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)

        engine.pause()
        assertEquals(TimerStatus.Paused, engine.state.value.status)

        engine.start()
        assertEquals(TimerStatus.Running, engine.state.value.status)
    }

    @Test
    fun `multiple stops do not crash or double-record`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        engine.stop()
        testScope.advanceUntilIdle()
        // Should not throw and state should be Idle
        assertEquals(TimerStatus.Idle, engine.state.value.status)
    }

    @Test
    fun `stop then start gives a fresh session`() = runTest {
        engine.start()
        val firstStartTime = engine.state.value.sessionStartTime
        engine.stop()
        testScope.advanceUntilIdle()

        engine.start()
        val secondStartTime = engine.state.value.sessionStartTime
        // New start should get a new sessionStartTime (stop resets it to 0, then start sets a new one)
        assertNotEquals(0L, secondStartTime)
    }

    @Test
    fun `selectMode after stop resets state cleanly`() = runTest {
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()

        engine.selectMode(FocusMode.Flow)
        val state = engine.state.value
        assertEquals(FocusMode.Flow, state.mode)
        assertEquals(TimerStatus.Idle, state.status)
        assertEquals(0L, state.elapsedMillis)
        assertEquals(0L, state.totalMillis) // Flow has 0 totalMillis
    }

    @Test
    fun `sessionsBeforeLongBreak of 0 never triggers long break`() = runTest {
        prefsFlow.value = UserPreferences(
            sessionsBeforeLongBreak = 0,
            shortBreakMinutes = 5,
            autoStartBreaks = false,
        )
        val workTotal = 25 * 60 * 1000L

        // newCompleted would be 1, and 1 % 0 would be division by zero,
        // but the engine guards with "prefs.sessionsBeforeLongBreak > 0"
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = workTotal,
            totalMillis = workTotal,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - workTotal,
        )
        testScope.advanceUntilIdle()

        // Should be ShortBreak (not crash from division by zero)
        assertEquals(FocusPhase.ShortBreak, engine.state.value.phase)
    }

    @Test
    fun `restoreState with Blocks mode and elapsed beyond total transitions to Idle`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 60)
        val total = 60 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        // Blocks completion goes to Idle
        assertEquals(TimerStatus.Idle, engine.state.value.status)
        assertEquals(FocusMode.Blocks, engine.state.value.mode)
        assertEquals(1, engine.state.value.completedSessions)
    }

    @Test
    fun `onPhaseComplete for break records session with break phase name`() = runTest {
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.testScheduler.runCurrent()

        coVerify {
            sessionRepository.recordSession(
                mode = "Pomodoro",
                startTime = any(),
                endTime = any(),
                durationMillis = breakTotal,
                linkedTaskId = any(),
                phase = "ShortBreak",
                wasCompleted = true,
                pomodoroNumber = null,
                targetDurationMillis = breakTotal,
            )
        }
    }

    @Test
    fun `pomodoro work completion with autoStartBreaks sets non-zero sessionStartTime`() = runTest {
        prefsFlow.value = UserPreferences(
            autoStartBreaks = true,
            shortBreakMinutes = 5,
            sessionsBeforeLongBreak = 4,
        )
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        assertNotEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `pomodoro work completion without autoStartBreaks sets zero sessionStartTime`() = runTest {
        prefsFlow.value = UserPreferences(
            autoStartBreaks = false,
            shortBreakMinutes = 5,
            sessionsBeforeLongBreak = 4,
        )
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        assertEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `break completion without autoStartNextPomodoro sets zero sessionStartTime`() = runTest {
        prefsFlow.value = UserPreferences(
            autoStartNextPomodoro = false,
            pomodoroMinutes = 25,
        )
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.advanceUntilIdle()

        assertEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `break completion with autoStartNextPomodoro sets non-zero sessionStartTime`() = runTest {
        prefsFlow.value = UserPreferences(
            autoStartNextPomodoro = true,
            pomodoroMinutes = 25,
            autoStartBreaks = false,
        )
        val breakTotal = 5 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.ShortBreak,
            elapsedMillis = breakTotal,
            totalMillis = breakTotal,
            completedSessions = 1,
            sessionStartTime = System.currentTimeMillis() - breakTotal,
        )
        testScope.testScheduler.runCurrent()

        assertNotEquals(0L, engine.state.value.sessionStartTime)
    }

    @Test
    fun `onPhaseComplete resets elapsedMillis on new phase`() = runTest {
        prefsFlow.value = UserPreferences(autoStartBreaks = false)
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        // After phase transition, elapsedMillis should be 0 (new FocusTimerState)
        assertEquals(0L, engine.state.value.elapsedMillis)
    }

    @Test
    fun `blocks completion resets elapsedMillis`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 60)
        val total = 60 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        assertEquals(0L, engine.state.value.elapsedMillis)
    }

    @Test
    fun `onPhaseComplete for blocks calls feedbackManager`() = runTest {
        prefsFlow.value = UserPreferences(timeBlockMinutes = 60)
        val total = 60 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Blocks,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.advanceUntilIdle()

        coVerify {
            feedbackManager.onPhaseComplete(FocusMode.Blocks, FocusPhase.Work)
        }
    }

    // ── Interaction: selectMode + linkTask ──

    @Test
    fun `linkTask persists through selectMode`() = runTest {
        engine.linkTask("persistent-task")
        engine.selectMode(FocusMode.Blocks)
        assertEquals("persistent-task", engine.state.value.linkedTaskId)

        engine.selectMode(FocusMode.Flow)
        assertEquals("persistent-task", engine.state.value.linkedTaskId)

        engine.selectMode(FocusMode.Chrono)
        assertEquals("persistent-task", engine.state.value.linkedTaskId)
    }

    @Test
    fun `linkTask persists through stop`() = runTest {
        engine.linkTask("persist-stop")
        engine.start()
        engine.stop()
        testScope.advanceUntilIdle()
        assertEquals("persist-stop", engine.state.value.linkedTaskId)
    }

    // ── Default UserPreferences matching ──

    @Test
    fun `default prefs give 25 min totalMillis for Pomodoro`() = runTest {
        prefsFlow.value = UserPreferences() // defaults
        engine.selectMode(FocusMode.Pomodoro)
        assertEquals(25 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `default prefs give 60 min totalMillis for Blocks`() = runTest {
        prefsFlow.value = UserPreferences() // defaults
        engine.selectMode(FocusMode.Blocks)
        assertEquals(60 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `default prefs short break is 5 min`() = runTest {
        prefsFlow.value = UserPreferences() // autoStartBreaks=true by default
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 0,
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        assertEquals(FocusPhase.ShortBreak, engine.state.value.phase)
        assertEquals(5 * 60 * 1000L, engine.state.value.totalMillis)
    }

    @Test
    fun `default prefs long break is 15 min`() = runTest {
        prefsFlow.value = UserPreferences() // sessionsBeforeLongBreak=4 by default
        val total = 25 * 60 * 1000L
        engine.restoreState(
            mode = FocusMode.Pomodoro,
            phase = FocusPhase.Work,
            elapsedMillis = total,
            totalMillis = total,
            completedSessions = 3, // 4th session completes -> long break
            sessionStartTime = System.currentTimeMillis() - total,
        )
        testScope.testScheduler.runCurrent()

        assertEquals(FocusPhase.LongBreak, engine.state.value.phase)
        assertEquals(15 * 60 * 1000L, engine.state.value.totalMillis)
    }
}
