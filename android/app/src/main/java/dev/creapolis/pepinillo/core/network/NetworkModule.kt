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
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
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
    ): HttpClient = HttpClient(OkHttp) {
        expectSuccess = true

        install(ContentNegotiation) { json(json) }

        install(Logging) { level = LogLevel.BODY }

        install(Auth) {
            bearer {
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
                            Log.w("NetworkModule", "Refresh token rejected ($status), clearing auth", e)
                            authStore.clearAll()
                        } else {
                            Log.w("NetworkModule", "HTTP error during token refresh ($status), keeping auth", e)
                        }
                        null
                    } catch (e: IOException) {
                        Log.w("NetworkModule", "Network error during token refresh, keeping auth", e)
                        null
                    } catch (e: Exception) {
                        Log.w("NetworkModule", "Unexpected error during token refresh, keeping auth", e)
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
