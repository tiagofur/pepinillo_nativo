package dev.creapolis.pepinillo.appfunctions

import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionSerializable
import androidx.appfunctions.AppFunctionServiceEntryPoint
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Gemini-facing AppFunctions for Pepinillo (issue #912).
 *
 * AppFunctions are the Android 16+ equivalent of App Intents: the platform
 * indexes the generated schema and authorized agents (Gemini, assistants)
 * invoke these functions with natural-language-derived parameters.
 * Requires [Connected Apps Platform](https://connected.google.com) enrollment
 * for agent invocation; local verification works via
 * `adb shell cmd app_function`.
 */
@RequiresApi(36)
@AndroidEntryPoint
@AppFunctionServiceEntryPoint(
    serviceName = "TaskAppFunctionService",
    appFunctionXmlFileName = "task_app_function_service",
)
abstract class BaseTaskAppFunctionService : AppFunctionService() {

    @Inject
    internal lateinit var createTaskFunction: CreateTaskFunction

    /**
     * Creates a new task in the user's Pepinillo deep-work plan.
     *
     * Use when the user wants to capture a to-do, e.g. "create a task in
     * Pepinillo to buy oat milk" or "add to Pepinillo that I have to call the
     * dentist". The task is appended to the end of the plan; no due date or
     * scheduling is set.
     *
     * @param title The task title derived from the user's request, e.g.
     *   "Buy oat milk". Required and non-blank; longer than 200 characters is
     *   truncated to match the in-app limit.
     * @param notes Optional extra details, e.g. "the barista oat one". Blank
     *   input collapses to no notes.
     * @return The created task with its id (for later updates) and stored
     *   title.
     * @throws AppFunctionInvalidArgumentException when the title is blank, or
     *   when the free plan already has 3 active tasks and the user is not a
     *   Pepinillo+ subscriber — the message tells the agent to suggest
     *   upgrading in the app.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun createTask(title: String, notes: String?): CreatedTask =
        withContext(Dispatchers.IO) {
            when (val result = createTaskFunction.invoke(title, notes)) {
                is CreateTaskFunction.Result.Created ->
                    CreatedTask(result.taskId, result.title, result.notes)
                is CreateTaskFunction.Result.Rejected -> when (result.reason) {
                    CreateTaskFunction.RejectionReason.BLANK_TITLE ->
                        throw AppFunctionInvalidArgumentException("A task needs a non-blank title.")
                    CreateTaskFunction.RejectionReason.FREE_TIER_LIMIT ->
                        throw AppFunctionInvalidArgumentException(
                            "The free plan allows up to 3 active tasks. " +
                                "Suggest upgrading to Pepinillo+ in the app for unlimited tasks."
                        )
                    CreateTaskFunction.RejectionReason.STORAGE_ERROR ->
                        // Uncaught exceptions surface as AppFunctionAppUnknownException.
                        throw IllegalStateException("Pepinillo could not save the task locally.")
                }
            }
        }
}

/** The task created on the user's behalf, exposed to the calling agent. */
@AppFunctionSerializable(isDescribedByKDoc = true)
data class CreatedTask(
    /** The id of the created task; use it for later updates or completion. */
    val taskId: String,
    /** The stored title of the task (trimmed, possibly truncated). */
    val title: String,
    /** The stored notes, or null when the user gave no details. */
    val notes: String?,
)
