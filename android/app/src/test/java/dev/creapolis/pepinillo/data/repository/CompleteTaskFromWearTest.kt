package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.TaskEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CompleteTaskFromWearTest {

    private lateinit var taskDao: TaskDao
    private lateinit var repo: TaskRepository

    @Before
    fun setUp() {
        taskDao = mockk(relaxed = true)
        val subtaskDao = mockk<SubtaskDao>(relaxed = true)
        val focusSessionDao = mockk<FocusSessionDao>(relaxed = true)
        val workManager = mockk<androidx.work.WorkManager>(relaxed = true)
        val sessionRepository = mockk<SessionRepository>(relaxed = true)
        val subscriptionManager = mockk<SubscriptionManager>(relaxed = true)
        every { subscriptionManager.subscriptionState } returns kotlinx.coroutines.flow.MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.FREE),
        )
        val featureGate = FeatureGate(subscriptionManager)
        val appContext = mockk<android.content.Context>(relaxed = true)
        val appScope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.SupervisorJob())

        repo = TaskRepository(
            taskDao = taskDao,
            subtaskDao = subtaskDao,
            focusSessionDao = focusSessionDao,
            workManager = workManager,
            sessionRepository = sessionRepository,
            featureGate = featureGate,
            appContext = appContext,
            appScope = appScope,
        )
    }

    @Test
    fun `completeTaskFromWear uses completeTaskAtomic for incomplete task`() = runTest {
        coEvery { taskDao.getTaskById("task-1") } returns TaskEntity(
            id = "task-1",
            title = "Test",
            isCompleted = false,
        )

        val result = repo.completeTaskFromWear("task-1")

        assertTrue(result.isSuccess)
        coVerify(exactly = 1) { taskDao.completeTaskAtomic("task-1", any()) }
        coVerify(exactly = 0) { taskDao.toggleCompletionAtomic(any(), any()) }
    }

    @Test
    fun `completeTaskFromWear is idempotent when already completed`() = runTest {
        coEvery { taskDao.getTaskById("task-1") } returns TaskEntity(
            id = "task-1",
            title = "Test",
            isCompleted = true,
            completedAt = 1L,
        )

        val result = repo.completeTaskFromWear("task-1")

        assertTrue(result.isSuccess)
        coVerify(exactly = 0) { taskDao.completeTaskAtomic(any(), any()) }
        coVerify(exactly = 0) { taskDao.toggleCompletionAtomic(any(), any()) }
    }
}