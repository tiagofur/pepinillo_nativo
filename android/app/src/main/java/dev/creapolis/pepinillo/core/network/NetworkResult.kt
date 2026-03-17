package dev.creapolis.pepinillo.core.network

sealed class NetworkResult<out T> {
    data class Success<T>(val data: T) : NetworkResult<T>()
    data class Error(val code: Int, val message: String) : NetworkResult<Nothing>()
    data class NetworkError(val exception: Throwable) : NetworkResult<Nothing>()
}
