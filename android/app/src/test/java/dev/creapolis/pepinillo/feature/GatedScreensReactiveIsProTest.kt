package dev.creapolis.pepinillo.feature

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.domain.soundscape.SoundscapeManager
import dev.creapolis.pepinillo.feature.more.ExportViewModel
import dev.creapolis.pepinillo.feature.soundscape.SoundscapePickerViewModel
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailViewModel
import dev.creapolis.pepinillo.feature.tasks.model.Task
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GatedScreensReactiveIsProTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private val subscriptionStateFlow = MutableStateFlow(SubscriptionState(tier = SubscriptionTier.FREE))

    private lateinit var featureGate: FeatureGate
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var prefsRepo: dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        subscriptionManager = mockk {
            every { subscriptionState } returns subscriptionStateFlow
        }
        featureGate = FeatureGate(subscriptionManager)
        prefsRepo = mockk {
            every { preferences } returns kotlinx.coroutines.flow.MutableStateFlow(
                dev.creapolis.pepinillo.data.local.preferences.UserPreferences()
            )
        }
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `ExportViewModel reflects purchase mid-session without recreation`() {
        val focusSessionDao = mockk<FocusSessionDao>(relaxed = true)
        val taskDao = mockk<TaskDao>(relaxed = true)
        val vm = ExportViewModel(focusSessionDao, taskDao, featureGate)

        assertFalse("Initially free tier", vm.uiState.value.isPro)

        // User purchases Plus mid-session
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)

        assertTrue("ExportViewModel.uiState.isPro must dynamically update to true", vm.uiState.value.isPro)
    }

    @Test
    fun `SoundscapePickerViewModel reflects purchase mid-session without recreation`() {
        val soundscapeManager = mockk<SoundscapeManager>(relaxed = true)
        val vm = SoundscapePickerViewModel(soundscapeManager, featureGate)

        assertFalse("Initially free tier", vm.uiState.value.isPro)

        // User purchases Plus mid-session
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)

        assertTrue("SoundscapePickerViewModel.uiState.isPro must dynamically update to true", vm.uiState.value.isPro)
    }

    @Test
    fun `TaskDetailViewModel reflects purchase mid-session without recreation`() {
        val taskRepository = mockk<TaskRepository>(relaxed = true) {
            every { getTaskByIdFlow(any()) } returns flowOf(Task(id = "task-1", title = "Test Task"))
            every { getSubtasksForTask(any()) } returns flowOf(emptyList())
            every { getSessionsForTask(any()) } returns flowOf(emptyList())
        }
        val vm = TaskDetailViewModel(taskRepository, featureGate, prefsRepo)
        vm.initialize("task-1")

        val job = testDispatcher.scheduler.runCurrent().let {
            kotlinx.coroutines.MainScope().launch(testDispatcher) {
                vm.uiState.collect {}
            }
        }

        assertFalse("Initially free tier", vm.uiState.value.isPro)

        // User purchases Plus mid-session
        subscriptionStateFlow.value = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)

        assertTrue("TaskDetailViewModel.uiState.isPro must dynamically update to true", vm.uiState.value.isPro)
        job.cancel()
    }
}
