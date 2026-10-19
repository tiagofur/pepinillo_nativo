package dev.creapolis.pepinillo.data.sync

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker.Result
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.domain.streak.StreakResult
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.WidgetStateManager
import dev.creapolis.pepinillo.widget.WidgetTaskStateManager
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkAll
import io.mockk.verify
import io.mockk.verifyOrder
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Locks down issue #551 mechanism B: the periodic/midnight widget refresh worker
 * must call [FocusEngine.onDayChanged] before reading stats, so widgets and Wear
 * reflect the new day even if the user never reopens the app.
 *
 * Only the wiring is asserted here (onDayChanged is invoked, worker succeeds);
 * the day-change semantics themselves are covered by FocusEngine and the
 * observer test. Singleton collaborators are stubbed with mockkObject.
 */
class WidgetRefreshWorkerTest {

    private lateinit var context: Context
    private lateinit var workerParams: WorkerParameters
    private lateinit var sessionRepository: SessionRepository
    private lateinit var taskRepository: TaskRepository
    private lateinit var featureGate: FeatureGate
    private lateinit var focusEngine: FocusEngine
    private lateinit var worker: WidgetRefreshWorker

    @Before
    fun setUp() = runTest {
        context = mockk(relaxed = true)
        workerParams = mockk(relaxed = true)
        sessionRepository = mockk()
        taskRepository = mockk()
        featureGate = mockk()
        focusEngine = mockk(relaxed = true)

        // Minimal stubs so doWork() can traverse its happy path.
        every { sessionRepository.getTodayStats() } returns flowOf(null)
        every { sessionRepository.getAllDaysWithSessions() } returns flowOf(emptyList())
        every { taskRepository.getActiveTasks() } returns flowOf(emptyList())
        coEvery { taskRepository.getCompletedTodayCount(any(), any()) } returns 0
        every { featureGate.isPro } returns false

        // Singleton collaborators (objects) — stubbed so doWork() doesn't NPE.
        mockkObject(WidgetStateManager)
        coEvery { WidgetStateManager.updateDailyStats(any(), any(), any(), any(), any()) } returns Unit
        mockkObject(WidgetTaskStateManager)
        coEvery { WidgetTaskStateManager.updateTasks(any(), any(), any()) } returns Unit
        mockkObject(WearDataLayerHelper)
        // pushTasksAndStats is NOT a suspend fun — it does its work synchronously.
        every { WearDataLayerHelper.pushTasksAndStats(any(), any(), any(), any(), any(), any()) } returns Unit
        mockkObject(MidnightWidgetRefreshScheduler)
        every { MidnightWidgetRefreshScheduler.schedule(any()) } returns Unit
        mockkObject(StreakProtectionService)
        every {
            StreakProtectionService.computeProtectedStreak(
                history = any(),
                isPro = any(),
                todayStartMs = any(),
                calendar = any(),
            )
        } returns StreakResult(days = 0, protectionApplied = false)

        worker = WidgetRefreshWorker(
            context,
            workerParams,
            sessionRepository,
            taskRepository,
            featureGate,
            focusEngine,
        )
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    @Test
    fun `doWork invokes focusEngine onDayChanged before reading stats`() = runTest {
        val result = worker.doWork()

        assertEquals(Result.success(), result)
        // Prove mechanism B: onDayChanged runs *before* the first repository read.
        // If the day rolled over and we read stats first, we'd emit yesterday's data.
        verifyOrder {
            focusEngine.onDayChanged()
            sessionRepository.getTodayStats()
        }
    }

    @Test
    fun `doWork still succeeds and calls onDayChanged when stats are non-null`() = runTest {
        // Sanity: a non-null stats row shouldn't change the day-reset wiring.
        every { sessionRepository.getTodayStats() } returns flowOf(
            DailyStatsEntity(date = 0L, totalMinutes = 50, sessionsCompleted = 2),
        )

        val result = worker.doWork()

        assertEquals(Result.success(), result)
        verify(exactly = 1) { focusEngine.onDayChanged() }
    }

    // P2(i): schedule() runs from app start, boot and worker reschedules — a plain
    // enqueue lets those calls pile up duplicate one-time refreshes. The immediate
    // refresh must be unique with REPLACE so later calls collapse earlier pending ones.
    @Test
    fun `schedule enqueues one-time refresh as unique REPLACE work`() {
        mockkObject(WorkManager.Companion)
        val workManager = mockk<WorkManager>(relaxed = true)
        every { WorkManager.getInstance(any()) } returns workManager

        WidgetRefreshWorker.schedule(context)

        verify(exactly = 1) {
            workManager.enqueueUniqueWork(
                any<String>(),
                eq(ExistingWorkPolicy.REPLACE),
                any<OneTimeWorkRequest>(),
            )
        }
        // PRESERVE: the periodic schedule itself stays unique-KEEP.
        verify(exactly = 1) {
            workManager.enqueueUniquePeriodicWork(
                any<String>(),
                eq(ExistingPeriodicWorkPolicy.KEEP),
                any<PeriodicWorkRequest>(),
            )
        }
    }
}
