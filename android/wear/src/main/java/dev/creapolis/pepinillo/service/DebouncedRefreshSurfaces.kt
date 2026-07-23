package dev.creapolis.pepinillo.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Debounced wrapper for refreshWearSurfaces() calls.
 * Collapses rapid DataItem updates into a single tile/complication refresh
 * within a configurable delay window (default 200ms).
 *
 * @param scope CoroutineScope for launching the delayed refresh
 * @param delayMs debounce delay in milliseconds
 * @param action the refresh action to invoke after debounce
 */
internal class DebouncedRefreshSurfaces(
    private val scope: CoroutineScope,
    private val delayMs: Long = 200L,
    private val action: () -> Unit,
) {
    private var pendingJob: Job? = null

    /**
     * Schedules a refresh. If called again before [delayMs] elapses,
     * the previous pending refresh is cancelled and replaced.
     */
    fun submit() {
        pendingJob?.cancel()
        pendingJob = scope.launch {
            delay(delayMs)
            action()
        }
    }
}
