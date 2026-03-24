package dev.creapolis.pepinillo.core.identity

import dev.creapolis.pepinillo.core.auth.AuthStore
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class IdentityManagerTest {

    private lateinit var authStore: AuthStore
    private lateinit var identityManager: IdentityManager

    @Before
    fun setUp() {
        authStore = mockk(relaxed = true)
    }

    // -----------------------------------------------------------------------
    // deriveState / identityState
    // -----------------------------------------------------------------------

    @Test
    fun `returns ANONYMOUS when no tokens`() {
        every { authStore.getAccessToken() } returns null
        identityManager = IdentityManager(authStore)
        assertEquals(IdentityState.ANONYMOUS, identityManager.identityState.value)
    }

    @Test
    fun `returns REGISTERED when tokens exist`() {
        every { authStore.getAccessToken() } returns "valid-token"
        identityManager = IdentityManager(authStore)
        assertEquals(IdentityState.REGISTERED, identityManager.identityState.value)
    }

    // -----------------------------------------------------------------------
    // isAnonymous
    // -----------------------------------------------------------------------

    @Test
    fun `isAnonymous returns true when no tokens`() {
        every { authStore.getAccessToken() } returns null
        identityManager = IdentityManager(authStore)
        assertTrue(identityManager.isAnonymous())
    }

    @Test
    fun `isAnonymous returns false when tokens exist`() {
        every { authStore.getAccessToken() } returns "valid-token"
        identityManager = IdentityManager(authStore)
        assertFalse(identityManager.isAnonymous())
    }

    // -----------------------------------------------------------------------
    // isAuthenticated
    // -----------------------------------------------------------------------

    @Test
    fun `isAuthenticated returns true when tokens exist`() {
        every { authStore.getAccessToken() } returns "valid-token"
        identityManager = IdentityManager(authStore)
        assertTrue(identityManager.isAuthenticated())
    }

    @Test
    fun `isAuthenticated returns false when no tokens`() {
        every { authStore.getAccessToken() } returns null
        identityManager = IdentityManager(authStore)
        assertFalse(identityManager.isAuthenticated())
    }

    // -----------------------------------------------------------------------
    // refreshState -- reactive updates
    // -----------------------------------------------------------------------

    @Test
    fun `state updates reactively when tokens change`() {
        every { authStore.getAccessToken() } returns null
        identityManager = IdentityManager(authStore)
        assertEquals(IdentityState.ANONYMOUS, identityManager.identityState.value)

        // Simulate token arrival
        every { authStore.getAccessToken() } returns "new-token"
        identityManager.refreshState()
        assertEquals(IdentityState.REGISTERED, identityManager.identityState.value)
    }

    @Test
    fun `state updates from REGISTERED to ANONYMOUS on token removal`() {
        every { authStore.getAccessToken() } returns "valid-token"
        identityManager = IdentityManager(authStore)
        assertEquals(IdentityState.REGISTERED, identityManager.identityState.value)

        // Simulate logout
        every { authStore.getAccessToken() } returns null
        identityManager.refreshState()
        assertEquals(IdentityState.ANONYMOUS, identityManager.identityState.value)
    }
}
