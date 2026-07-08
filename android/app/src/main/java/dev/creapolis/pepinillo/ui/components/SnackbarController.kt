package dev.creapolis.pepinillo.ui.components

import android.content.Context
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * App-wide snackbar dispatcher bound to the root [SnackbarHostState].
 *
 * [show] accepts either a String resource id (Int) or a literal String for [message],
 * matching the existing per-VM patterns (tasks/auth). Resolves resource ids via the
 * provided [Context] so callers don't have to.
 *
 * Obtain via [LocalSnackbarController] inside the composition.
 */
class SnackbarController internal constructor(
    private val context: Context,
    private val scope: CoroutineScope,
    val hostState: SnackbarHostState,
) {
    fun show(
        message: Any,
        vararg formatArgs: Any,
        duration: SnackbarDuration = SnackbarDuration.Short,
        actionLabel: Any? = null,
        onAction: (() -> Unit)? = null,
    ) {
        scope.launch {
            val text = resolve(message, formatArgs)
            val actionText = actionLabel?.let { resolve(it, emptyArray()) }
            val result = if (actionText != null) {
                hostState.showSnackbar(
                    message = text,
                    actionLabel = actionText,
                    duration = duration,
                )
            } else {
                hostState.showSnackbar(message = text, duration = duration)
            }
            if (result == SnackbarResult.ActionPerformed) {
                onAction?.invoke()
            }
        }
    }

    private fun resolve(value: Any, formatArgs: Array<out Any>): String = when (value) {
        is Int -> if (formatArgs.isEmpty()) context.getString(value)
                  else context.getString(value, *formatArgs)
        is String -> value
        else -> value.toString()
    }
}

/** Provides the app-wide [SnackbarController]. Set up at the root Scaffold. */
val LocalSnackbarController = compositionLocalOf<SnackbarController?> { null }

/**
 * Creates and remembers a [SnackbarController] bound to a new [SnackbarHostState].
 * The returned [SnackbarController.hostState] should be wired into the Scaffold's
 * `snackbarHost` slot.
 */
@Composable
fun rememberSnackbarController(): SnackbarController {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val hostState = remember { SnackbarHostState() }
    return remember(context, scope, hostState) { SnackbarController(context, scope, hostState) }
}
