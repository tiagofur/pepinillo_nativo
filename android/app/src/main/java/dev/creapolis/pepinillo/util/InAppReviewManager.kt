package dev.creapolis.pepinillo.util

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.google.android.play.core.review.ReviewManagerFactory
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InAppReviewManager @Inject constructor(
    private val prefsRepo: UserPreferencesRepository,
) {
    companion object {
        private const val TAG = "InAppReviewManager"
        const val SESSIONS_THRESHOLD_FOR_REVIEW = 3
    }

    /**
     * Checks if the user is eligible for an in-app review prompt.
     * Criteria:
     * 1. Has completed at least [SESSIONS_THRESHOLD_FOR_REVIEW] (3) focus sessions.
     * 2. Has NEVER been prompted before on this device.
     *
     * Once requested, [hasPromptedForReview] is immediately marked as true,
     * ensuring the user is NEVER bothered again.
     */
    suspend fun checkAndPromptReview(activity: Activity) {
        val prefs = prefsRepo.preferences.first()
        if (prefs.hasPromptedForReview) {
            return
        }
        if (prefs.completedSessionsCount < SESSIONS_THRESHOLD_FOR_REVIEW) {
            return
        }

        // Permanently record that we prompted, ensuring zero repeated popups
        prefsRepo.markReviewPrompted()

        try {
            val manager = ReviewManagerFactory.create(activity)
            val request = manager.requestReviewFlow()
            request.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val reviewInfo = task.result
                    manager.launchReviewFlow(activity, reviewInfo)
                } else {
                    Log.w(TAG, "Review flow request failed: ${task.exception?.message}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error launching in-app review", e)
        }
    }

    /**
     * Opens the Play Store listing directly if the user manually taps
     * "Rate app" from Settings / More.
     */
    fun openPlayStore(context: Context) {
        val packageName = context.packageName
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(webIntent)
        }
    }
}

/**
 * Finds the Activity from any Context (including themed Compose wrappers).
 */
tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
