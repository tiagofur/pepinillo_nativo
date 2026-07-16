package dev.creapolis.pepinillo.core.auth

import android.content.Context
import android.content.SharedPreferences
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.GeneralSecurityException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Unit tests for AuthStore correctness (Sub-fase 2B-2):
 *  - synchronized writes
 *  - device-id atomic creation under concurrency
 *  - token cache invalidation
 *  - fail-soft fallback when EncryptedSharedPreferences cannot be created
 *
 * Strategy: override the protected `createEncryptedPrefs()` test seam to return an
 * in-memory fake, avoiding the Android Keystore entirely on the JVM.
 */
class AuthStoreTest {

    private lateinit var fakePrefs: FakeSharedPreferences
    private lateinit var context: Context

    private fun createStore(): AuthStore {
        fakePrefs = FakeSharedPreferences()
        context = mockk(relaxed = true)
        every { context.getSharedPreferences(any(), any()) } returns fakePrefs
        return object : AuthStore(context) {
            override fun createEncryptedPrefs(): SharedPreferences = fakePrefs
        }
    }

    private fun createFallbackStore(): AuthStore {
        // Encrypted creation always throws -> exercises the fail-soft fallback path.
        fakePrefs = FakeSharedPreferences()
        context = mockk(relaxed = true)
        every { context.getSharedPreferences(any(), any()) } returns fakePrefs
        return object : AuthStore(context) {
            override fun createEncryptedPrefs(): SharedPreferences {
                throw GeneralSecurityException("simulated keystore corruption")
            }
        }
    }

    // ------------------------------------------------------------------------
    // Token cache invalidation
    // ------------------------------------------------------------------------

    @Test
    fun `saveTokens stores tokens and getAccessToken returns cached value`() = runBlocking {
        val store = createStore()
        store.saveTokens("access-123", "refresh-456")

        assertEquals("access-123", store.getAccessToken())
        assertEquals("refresh-456", store.getRefreshToken())
        assertTrue(store.isLoggedIn.first())
    }

    @Test
    fun `getBearerTokens returns both tokens when present`() = runBlocking {
        val store = createStore()
        store.saveTokens("a", "r")

        val bearer = store.getBearerTokens()
        assertNotNull(bearer)
        assertEquals("a", bearer!!.accessToken)
        assertEquals("r", bearer.refreshToken)
    }

    @Test
    fun `saveTokens invalidates the previously cached access token`() = runBlocking {
        val store = createStore()
        store.saveTokens("old", "old-r")
        // warm cache
        assertEquals("old", store.getAccessToken())

        store.saveTokens("new", "new-r")

        assertEquals("new", store.getAccessToken())
        assertEquals("new-r", store.getRefreshToken())
    }

    @Test
    fun `clearAll invalidates token cache and sets logged out`() = runBlocking {
        val store = createStore()
        store.saveTokens("a", "r")
        // warm cache
        assertEquals("a", store.getAccessToken())

        store.clearAll()

        assertNull(store.getAccessToken())
        assertNull(store.getRefreshToken())
        assertEquals(false, store.isLoggedIn.first())
    }

    @Test
    fun `clearAll preserves device id across logouts`() = runBlocking {
        val store = createStore()
        val deviceId = store.getOrCreateDeviceId()
        store.saveTokens("a", "r")
        store.saveUser("u1", "name", "e@x.com")

        store.clearAll()

        // Device id preserved; user/tokens cleared.
        assertEquals(deviceId, store.getOrCreateDeviceId())
        assertNull(store.getUserId())
    }

    // ------------------------------------------------------------------------
    // Device-id atomic creation
    // ------------------------------------------------------------------------

    @Test
    fun `getOrCreateDeviceId returns the same id on repeated calls`() = runBlocking {
        val store = createStore()
        val first = store.getOrCreateDeviceId()
        val second = store.getOrCreateDeviceId()

        assertNotNull(first)
        assertEquals(first, second)
    }

    @Test
    fun `getOrCreateDeviceId is atomic under concurrent first-callers`() {
        // Fresh fake prefs: no device id yet, so all threads race through the first branch.
        val store = createStore()
        val threadCount = 16
        val startGate = CountDownLatch(1)
        val doneLatch = CountDownLatch(threadCount)
        val results = mutableListOf<String>()
        val resultsLock = Any()

        val threads = (1..threadCount).map {
            Thread {
                startGate.await()
                val id = store.getOrCreateDeviceId()
                synchronized(resultsLock) { results.add(id) }
                doneLatch.countDown()
            }
        }
        threads.forEach { it.start() }
        startGate.countDown() // release all threads simultaneously to maximize contention

        assertTrue("threads timed out", doneLatch.await(5, TimeUnit.SECONDS))
        val distinct = results.toSet()
        assertEquals(
            "All threads must observe the same device id; got $distinct",
            1,
            distinct.size,
        )
    }

    // ------------------------------------------------------------------------
    // Synchronized writes
    // ------------------------------------------------------------------------

    @Test
    fun `concurrent saveTokens calls leave a consistent final state`() = runBlocking {
        val store = createStore()
        val threadCount = 8
        val startGate = CountDownLatch(1)
        val doneLatch = CountDownLatch(threadCount)

        val threads = (1..threadCount).map { i ->
            Thread {
                startGate.await()
                store.saveTokens("access-$i", "refresh-$i")
                doneLatch.countDown()
            }
        }
        threads.forEach { it.start() }
        startGate.countDown()

        assertTrue("threads timed out", doneLatch.await(5, TimeUnit.SECONDS))

        // Final token must be exactly one of the written values (no corruption / partial write).
        val finalAccess = store.getAccessToken()
        val finalRefresh = store.getRefreshToken()
        assertNotNull(finalAccess)
        assertNotNull(finalRefresh)
        assertTrue(finalAccess!!.startsWith("access-"))
        assertTrue(finalRefresh!!.startsWith("refresh-"))
        assertTrue(store.isLoggedIn.first())
    }

    // ------------------------------------------------------------------------
    // Fail-soft fallback
    // ------------------------------------------------------------------------

    @Test
    fun `fails closed when encrypted storage is unrecoverable — no plaintext fallback`() = runBlocking {
        // #349: When EncryptedSharedPreferences cannot be opened even after retry, the
        // store must NOT fall back to plaintext SharedPreferences. Instead it throws
        // AuthStorageUnavailableException so the caller forces re-login.
        val store = createFallbackStore()

        val exception = org.junit.Assert.assertThrows(AuthStore.AuthStorageUnavailableException::class.java) {
            // Triggering prefs lazy init via any operation that reads/writes prefs
            store.saveTokens("should", "fail")
        }
        org.junit.Assert.assertTrue(
            "Exception message should mention fail-closed behavior",
            exception.message!!.contains("Failing closed"),
        )
    }

    @Test
    fun `saveUser with emailVerified persists and isEmailVerified reads it back`() = runBlocking {
        val store = createStore()

        store.saveUser("u1", "name", "e@x.com", emailVerified = true)
        assertTrue(store.isEmailVerified())

        store.saveUser("u1", "name", "e@x.com", emailVerified = false)
        assertFalse(store.isEmailVerified())
    }

    @Test
    fun `saveUser defaults emailVerified to false when not specified`() = runBlocking {
        val store = createStore()

        store.saveUser("u1", "name", "e@x.com")
        assertFalse(store.isEmailVerified())
    }

    @Test
    fun `clearAll resets emailVerified`() = runBlocking {
        val store = createStore()
        store.saveTokens("a", "r")
        store.saveUser("u1", "name", "e@x.com", emailVerified = true)
        assertTrue(store.isEmailVerified())

        store.clearAll()
        assertFalse(store.isEmailVerified())
    }

    @Test
    fun `safeRead does not clear auth on transient SecurityException`() = runBlocking {
        val store = createStore()
        store.saveTokens("a", "r")
        store.saveUser("u1", "name", "e@x.com")
        assertTrue(store.isLoggedIn.first())

        // Force every subsequent prefs read to throw a transient SecurityException.
        fakePrefs.throwOnRead = true

        // getUserId() is NOT cached, so this exercises safeRead directly.
        assertNull(store.getUserId())

        // Critically: a transient read failure must NOT have cleared the session.
        // (Before the fix, safeRead called clearAll() and flipped _isLoggedIn to false.)
        assertTrue(store.isLoggedIn.first())
        // Cached access token is still served from memory despite prefs being unreadable.
        assertEquals("a", store.getAccessToken())
    }

    // ------------------------------------------------------------------------
    // In-memory SharedPreferences fake
    // ------------------------------------------------------------------------

    private class FakeSharedPreferences : SharedPreferences {
        private val map = mutableMapOf<String, Any?>()
        private val lock = Any()
        private val listeners = mutableListOf<SharedPreferences.OnSharedPreferenceChangeListener>()

        /** When true, every read accessor throws SecurityException (simulates transient crypto error). */
        @Volatile
        var throwOnRead: Boolean = false

        private fun <T> reading(block: () -> T): T {
            if (throwOnRead) throw SecurityException("simulated transient crypto error")
            return synchronized(lock) { block() }
        }

        override fun getAll(): Map<String, *> = reading { map.toMap() }
        override fun getString(key: String, defValue: String?): String? =
            reading { (map[key] as? String) ?: defValue }

        @Suppress("UNCHECKED_CAST")
        override fun getStringSet(key: String, defValues: Set<String>?): Set<String>? =
            reading { (map[key] as? Set<String>) ?: defValues }

        override fun getInt(key: String, defValue: Int): Int =
            reading { (map[key] as? Int) ?: defValue }

        override fun getLong(key: String, defValue: Long): Long =
            reading { (map[key] as? Long) ?: defValue }

        override fun getFloat(key: String, defValue: Float): Float =
            reading { (map[key] as? Float) ?: defValue }

        override fun getBoolean(key: String, defValue: Boolean): Boolean =
            reading { (map[key] as? Boolean) ?: defValue }

        override fun contains(key: String): Boolean = reading { map.containsKey(key) }

        override fun edit(): SharedPreferences.Editor = Editor()

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener,
        ) {
            synchronized(lock) { listeners.add(listener) }
        }

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener,
        ) {
            synchronized(lock) { listeners.remove(listener) }
        }

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
                    val changedKeys = pending.keys.toList()
                    listeners.forEach { l ->
                        changedKeys.forEach { k ->
                            l.onSharedPreferenceChanged(this@FakeSharedPreferences, k)
                        }
                    }
                }
            }
        }
    }

    private companion object {
        private val REMOVE_SENTINEL = Any()
    }
}
