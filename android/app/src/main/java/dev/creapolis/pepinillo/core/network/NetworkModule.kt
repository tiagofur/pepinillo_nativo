package dev.creapolis.pepinillo.core.network

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dev.creapolis.pepinillo.core.auth.AuthStore
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.auth.Auth
import io.ktor.client.plugins.auth.providers.BearerTokens
import io.ktor.client.plugins.auth.providers.bearer
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.call.body
import io.ktor.client.plugins.ClientRequestException
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.plugins.logging.Logger
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import android.util.Log
import dev.creapolis.pepinillo.BuildConfig
import java.io.IOException
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private val BASE_URL = BuildConfig.BASE_URL

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    @Provides
    @Singleton
    fun provideHttpClient(
        json: Json,
        authStore: AuthStore,
        authExpiredEvent: AuthExpiredEvent,
    ): HttpClient = HttpClient(OkHttp) {
        expectSuccess = true

        install(ContentNegotiation) { json(json) }

        install(Logging) {
            // Never log full bodies — auth responses contain accessToken/refreshToken and
            // login/register POST bodies contain passwords. HEADERS in DEBUG only, with
            // Authorization redacted.
            level = if (BuildConfig.DEBUG) LogLevel.HEADERS else LogLevel.NONE
            sanitizeHeader { header -> header == HttpHeaders.Authorization }
        }

        install(Auth) {
            bearer {
                // Do NOT attach bearer tokens to public auth endpoints. When a half-session
                // exists (e.g. unverified tokens), login/register/forgot/verify must not
                // carry stale Authorization headers (#348).
                sendWithoutRequest { request ->
                    val urlString = request.url.buildString()
                    !urlString.contains("/auth/login") &&
                        !urlString.contains("/auth/register") &&
                        !urlString.contains("/auth/google") &&
                        !urlString.contains("/auth/forgot-password") &&
                        !urlString.contains("/auth/reset-password") &&
                        !urlString.contains("/auth/verify-email") &&
                        !urlString.contains("/auth/resend-verification")
                }
                loadTokens {
                    authStore.getBearerTokens()
                }
                refreshTokens {
                    val refreshToken = authStore.getRefreshToken() ?: return@refreshTokens null
                    try {
                        val response: RefreshResponse = client.post("auth/refresh") {
                            setBody(RefreshRequest(refreshToken))
                            contentType(ContentType.Application.Json)
                            markAsRefreshTokenRequest()
                        }.body()
                        authStore.saveTokens(
                            response.tokens.accessToken,
                            response.tokens.refreshToken,
                        )
                        BearerTokens(response.tokens.accessToken, response.tokens.refreshToken)
                    } catch (e: ClientRequestException) {
                        val status = e.response.status
                        if (status == HttpStatusCode.Unauthorized || status == HttpStatusCode.Forbidden) {
                            Log.w("NetworkModule", "Refresh token rejected ($status), clearing auth")
                            authStore.clearAll()
                            // Signal the UI layer to force re-auth instead of leaving the
                            // user on a stale "logged-in" screen with silent sync failures.
                            authExpiredEvent.emit()
                        } else {
                            Log.w("NetworkModule", "HTTP error during token refresh ($status), keeping auth")
                        }
                        null
                    } catch (e: IOException) {
                        Log.w("NetworkModule", "Network error during token refresh, keeping auth")
                        null
                    } catch (e: Exception) {
                        Log.w("NetworkModule", "Unexpected error during token refresh, keeping auth")
                        null
                    }
                }
            }
        }

        defaultRequest {
            url(BASE_URL)
        }
    }
}
