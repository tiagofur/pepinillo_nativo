package dev.creapolis.pepinillo.core.auth

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.annotation.VisibleForTesting
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import io.ktor.client.plugins.auth.providers.BearerTokens
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.security.GeneralSecurityException
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
open class AuthStore @Inject constructor(
    @param:ApplicationContext protected val context: Context,
) {
    private companion object {
        const val TAG = "AuthStore"
        const val PREFS_NAME = "pepinillo_auth"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_USER_ID = "user_id"
        const val KEY_USER_NAME = "user_name"
        const val KEY_USER_EMAIL = "user_email"
        const val KEY_EMAIL_VERIFIED = "email_verified"
        const val KEY_DEVICE_ID = "device_id"
    }

    /**
     * True when EncryptedSharedPreferences failed unrecoverably and this store degraded to
     * an in-memory, process-local session (B3). While true the app starts anonymous
     * (isLoggedIn=false) and credentials never touch disk — observers can use this flag to
     * surface a re-login prompt.
     */
    private val _storageUnavailable = MutableStateFlow(false)
    val storageUnavailable: StateFlow<Boolean> = _storageUnavailable.asStateFlow()

    /**
     * Fail-soft lazy initializer.
     *
     * 1. Try EncryptedSharedPreferences.
     * 2. On failure, clear the corrupted file and retry once.
     * 3. If the retry also throws, degrade to an in-memory store (B3): no exception escapes
     *    this initializer. Previously the throw crashed every first-touch caller — including
     *    Hilt's @Singleton provisioning — in a startup crash loop. The degraded store keeps
     *    the session anonymous (null tokens, isLoggedIn=false) and still never falls back to
     *    plaintext on-disk storage.
     */
    private val prefs: SharedPreferences by lazy {
        try {
            createEncryptedPrefs()
        } catch (e: Exception) {
            Log.e(TAG, "EncryptedSharedPreferences first creation failed; clearing and retrying", e)
            try {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit().clear().commit()
                context.deleteSharedPreferences(PREFS_NAME)
                createEncryptedPrefs()
            } catch (e2: Exception) {
                Log.e(
                    TAG,
                    "EncryptedSharedPreferences unrecoverable after retry; degrading to " +
                        "in-memory auth store (anonymous session, re-login required)",
                    e2,
                )
                _storageUnavailable.value = true
                InMemorySharedPreferences()
            }
        }
    }

    /**
     * Creates the EncryptedSharedPreferences instance. Extracted as a protected open method so
     * JVM unit tests can substitute a fake without exercising the Android Keystore.
     */
    @VisibleForTesting
    protected open fun createEncryptedPrefs(): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    // --- In-memory caches (avoid synchronous decrypt on every getter call) ---
    @Volatile
    private var cachedAccessToken: String? = null
    @Volatile
    private var cachedRefreshToken: String? = null
    @Volatile
    private var cachedDeviceId: String? = null

    private val _isLoggedIn = MutableStateFlow(getAccessToken() != null)
    val isLoggedIn: Flow<Boolean> = _isLoggedIn.asStateFlow()

    fun getAccessToken(): String? {
        cachedAccessToken?.let { return it }
        val token = safeRead { prefs.getString(KEY_ACCESS_TOKEN, null) }
        // Only cache non-null values so a transient read failure forces a re-read next time
        // instead of pinning a stale null.
        if (token != null) cachedAccessToken = token
        return token
    }

    fun getRefreshToken(): String? {
        cachedRefreshToken?.let { return it }
        val token = safeRead { prefs.getString(KEY_REFRESH_TOKEN, null) }
        if (token != null) cachedRefreshToken = token
        return token
    }

    fun getBearerTokens(): BearerTokens? {
        val access = getAccessToken() ?: return null
        val refresh = getRefreshToken() ?: return null
        return BearerTokens(access, refresh)
    }

    fun saveTokens(accessToken: String, refreshToken: String) {
        // synchronized protects: cache invalidation+repopulation, prefs write, and the
        // _isLoggedIn update as one atomic step (concurrent saveTokens/clearAll races
        // previously could interleave clear+restore in clearAll).
        synchronized(this) {
            cachedAccessToken = null
            cachedRefreshToken = null
            prefs.edit()
                .putString(KEY_ACCESS_TOKEN, accessToken)
                .putString(KEY_REFRESH_TOKEN, refreshToken)
                .apply()
            cachedAccessToken = accessToken
            cachedRefreshToken = refreshToken
            _isLoggedIn.value = true
        }
    }

    fun saveUser(id: String, name: String, email: String, emailVerified: Boolean = false) {
        synchronized(this) {
            prefs.edit()
                .putString(KEY_USER_ID, id)
                .putString(KEY_USER_NAME, name)
                .putString(KEY_USER_EMAIL, email)
                .putBoolean(KEY_EMAIL_VERIFIED, emailVerified)
                .apply()
        }
    }

    fun getUserId(): String? = safeRead { prefs.getString(KEY_USER_ID, null) }
    fun getUserName(): String? = safeRead { prefs.getString(KEY_USER_NAME, null) }
    fun getUserEmail(): String? = safeRead { prefs.getString(KEY_USER_EMAIL, null) }

    /**
     * Whether the current session's email has been verified. Persisted alongside tokens
     * so that cold-start can gate unverified sessions to the verification screen instead
     * of treating them as fully authenticated.
     *
     * Returns false if the key is absent (legacy sessions pre-dating this field will be
     * re-verified on next handleAuthSuccess which always writes the flag).
     */
    fun isEmailVerified(): Boolean = safeRead { prefs.getBoolean(KEY_EMAIL_VERIFIED, false) } ?: false

    /**
     * Atomic device-id creation: double-checked locking + @Volatile cache. Two concurrent
     * first-callers previously each generated a different UUID and the last writer won,
     * leaking the other id to its caller.
     */
    fun getOrCreateDeviceId(): String {
        cachedDeviceId?.let { return it }
        synchronized(this) {
            cachedDeviceId?.let { return it }
            val existing = safeRead { prefs.getString(KEY_DEVICE_ID, null) }
            if (existing != null) {
                cachedDeviceId = existing
                return existing
            }
            val newId = UUID.randomUUID().toString()
            // commit() (not apply()) so the id is durable on disk before we return it —
            // first creation is a one-time cost worth making synchronous.
            prefs.edit().putString(KEY_DEVICE_ID, newId).commit()
            cachedDeviceId = newId
            return newId
        }
    }

    fun clearAll() {
        synchronized(this) {
            // Preserve deviceId across logouts — it identifies this install, not this account.
            val deviceId = cachedDeviceId ?: prefs.getString(KEY_DEVICE_ID, null)
            cachedAccessToken = null
            cachedRefreshToken = null
            prefs.edit().clear().commit()
            if (deviceId != null) {
                // commit() so the preserved id survives even if the process dies right after.
                prefs.edit().putString(KEY_DEVICE_ID, deviceId).commit()
                cachedDeviceId = deviceId
            }
            _isLoggedIn.value = false
        }
    }

    /**
     * Read guard. A transient crypto/keystore error (e.g. boot-before-unlock FBE state) must
     * NOT wipe the session — the underlying data is likely still valid. Only explicit logout
     * (clearAll) or a user-initiated recovery should clear auth. Previously a SecurityException
     * here called clearAll(), logging the user out on transient errors.
     */
    private fun <T> safeRead(block: () -> T): T? {
        return try {
            block()
        } catch (e: SecurityException) {
            Log.e(TAG, "Transient SecurityException reading encrypted pref; keeping auth", e)
            null
        } catch (e: GeneralSecurityException) {
            Log.e(TAG, "Transient GeneralSecurityException reading encrypted pref; keeping auth", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read encrypted pref, keeping auth", e)
            null
        }
    }
}

/**
 * Process-local [SharedPreferences] used only as the degraded fallback when
 * EncryptedSharedPreferences cannot be created (B3). It keeps a freshly-signed-in session
 * usable for the current process without ever persisting credentials to disk.
 */
private class InMemorySharedPreferences : SharedPreferences {
    private val map = mutableMapOf<String, Any?>()
    private val lock = Any()

    override fun getAll(): Map<String, *> = synchronized(lock) { map.toMap() }

    override fun getString(key: String, defValue: String?): String? =
        synchronized(lock) { map[key] as? String ?: defValue }

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String, defValues: Set<String>?): Set<String>? =
        synchronized(lock) { map[key] as? Set<String> ?: defValues }

    override fun getInt(key: String, defValue: Int): Int =
        synchronized(lock) { map[key] as? Int ?: defValue }

    override fun getLong(key: String, defValue: Long): Long =
        synchronized(lock) { map[key] as? Long ?: defValue }

    override fun getFloat(key: String, defValue: Float): Float =
        synchronized(lock) { map[key] as? Float ?: defValue }

    override fun getBoolean(key: String, defValue: Boolean): Boolean =
        synchronized(lock) { map[key] as? Boolean ?: defValue }

    override fun contains(key: String): Boolean = synchronized(lock) { map.containsKey(key) }

    override fun edit(): SharedPreferences.Editor = Editor()

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener,
    ) = Unit

    private inner class Editor : SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private var clearFirst = false

        override fun putString(key: String, value: String?): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun putStringSet(key: String, value: Set<String>?): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun putInt(key: String, value: Int): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun putLong(key: String, value: Long): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun putFloat(key: String, value: Float): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun putBoolean(key: String, value: Boolean): SharedPreferences.Editor {
            pending[key] = value; return this
        }

        override fun remove(key: String): SharedPreferences.Editor {
            pending[key] = REMOVE_SENTINEL; return this
        }

        override fun clear(): SharedPreferences.Editor {
            clearFirst = true; return this
        }

        override fun commit(): Boolean {
            apply(); return true
        }

        override fun apply() {
            synchronized(lock) {
                if (clearFirst) map.clear()
                pending.forEach { (k, v) ->
                    if (v === REMOVE_SENTINEL) map.remove(k) else map[k] = v
                }
            }
        }
    }

    private companion object {
        private val REMOVE_SENTINEL = Any()
    }
}
