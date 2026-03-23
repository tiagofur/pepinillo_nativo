package dev.creapolis.pepinillo.core.auth

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.plugins.auth.providers.BearerTokens
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.security.GeneralSecurityException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private companion object {
        const val TAG = "AuthStore"
        const val PREFS_NAME = "pepinillo_auth"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_USER_ID = "user_id"
        const val KEY_USER_NAME = "user_name"
        const val KEY_USER_EMAIL = "user_email"
    }

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        try {
            EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        } catch (e: Exception) {
            Log.e(TAG, "EncryptedSharedPreferences corrupted, clearing", e)
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
            context.deleteSharedPreferences(PREFS_NAME)
            EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }

    private val _isLoggedIn = MutableStateFlow(getAccessToken() != null)
    val isLoggedIn: Flow<Boolean> = _isLoggedIn.asStateFlow()

    fun getAccessToken(): String? = safeRead { prefs.getString(KEY_ACCESS_TOKEN, null) }

    fun getRefreshToken(): String? = safeRead { prefs.getString(KEY_REFRESH_TOKEN, null) }

    fun getBearerTokens(): BearerTokens? {
        val access = getAccessToken() ?: return null
        val refresh = getRefreshToken() ?: return null
        return BearerTokens(access, refresh)
    }

    fun saveTokens(accessToken: String, refreshToken: String) {
        prefs.edit()
            .putString(KEY_ACCESS_TOKEN, accessToken)
            .putString(KEY_REFRESH_TOKEN, refreshToken)
            .apply()
        _isLoggedIn.value = true
    }

    fun saveUser(id: String, name: String, email: String) {
        prefs.edit()
            .putString(KEY_USER_ID, id)
            .putString(KEY_USER_NAME, name)
            .putString(KEY_USER_EMAIL, email)
            .apply()
    }

    fun getUserId(): String? = safeRead { prefs.getString(KEY_USER_ID, null) }
    fun getUserName(): String? = safeRead { prefs.getString(KEY_USER_NAME, null) }
    fun getUserEmail(): String? = safeRead { prefs.getString(KEY_USER_EMAIL, null) }

    fun clearAll() {
        prefs.edit().clear().apply()
        _isLoggedIn.value = false
    }

    private fun <T> safeRead(block: () -> T): T? {
        return try {
            block()
        } catch (e: SecurityException) {
            Log.e(TAG, "Security error reading encrypted pref, clearing corrupted data", e)
            clearAll()
            null
        } catch (e: GeneralSecurityException) {
            Log.e(TAG, "Crypto error reading encrypted pref, clearing corrupted data", e)
            clearAll()
            null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read encrypted pref, keeping auth", e)
            null
        }
    }
}
