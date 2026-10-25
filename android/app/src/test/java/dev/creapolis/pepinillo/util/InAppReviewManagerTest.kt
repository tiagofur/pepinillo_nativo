package dev.creapolis.pepinillo.util

import android.app.Activity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test

class InAppReviewManagerTest {

    private lateinit var prefsRepo: UserPreferencesRepository
    private lateinit var activity: Activity
    private lateinit var reviewManager: InAppReviewManager

    @Before
    fun setUp() {
        prefsRepo = mockk(relaxed = true)
        activity = mockk(relaxed = true)
        reviewManager = InAppReviewManager(prefsRepo)
    }

    @Test
    fun `when already prompted, does nothing and never requests review again`() = runTest {
        coEvery { prefsRepo.preferences } returns flowOf(
            UserPreferences(
                hasPromptedForReview = true,
                completedSessionsCount = 10,
            )
        )

        reviewManager.checkAndPromptReview(activity)

        coVerify(exactly = 0) { prefsRepo.markReviewPrompted() }
    }

    @Test
    fun `when completed sessions less than threshold, does nothing`() = runTest {
        coEvery { prefsRepo.preferences } returns flowOf(
            UserPreferences(
                hasPromptedForReview = false,
                completedSessionsCount = 2,
            )
        )

        reviewManager.checkAndPromptReview(activity)

        coVerify(exactly = 0) { prefsRepo.markReviewPrompted() }
    }

    @Test
    fun `when 3 or more sessions and not yet prompted, immediately marks review prompted`() = runTest {
        coEvery { prefsRepo.preferences } returns flowOf(
            UserPreferences(
                hasPromptedForReview = false,
                completedSessionsCount = 3,
            )
        )

        reviewManager.checkAndPromptReview(activity)

        // Verifies the "never prompt again" flag is permanently set upon launch
        coVerify(exactly = 1) { prefsRepo.markReviewPrompted() }
    }
}
