package dev.creapolis.pepinillo.core.result

/**
 * Represents the state of data flowing from repositories to ViewModels.
 * Used to distinguish between loading, success (even with empty data), and error states.
 */
sealed class DataState<out T> {
    data object Loading : DataState<Nothing>()
    data class Success<T>(val data: T) : DataState<T>()
    data class Error(val message: String, val cause: Throwable? = null) : DataState<Nothing>()
}

/** Returns the data if this is [DataState.Success], otherwise returns [default]. */
fun <T> DataState<T>.dataOrElse(default: T): T = when (this) {
    is DataState.Success -> data
    else -> default
}
