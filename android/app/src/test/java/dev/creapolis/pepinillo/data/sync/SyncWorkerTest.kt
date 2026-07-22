package dev.creapolis.pepinillo.data.sync

import android.content.Context
import androidx.work.ListenableWorker.Result
import androidx.work.WorkerParameters
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class SyncWorkerTest {

    private lateinit var context: Context
    private lateinit var workerParams: WorkerParameters
    private lateinit var syncEngine: SyncEngine
    private lateinit var syncWorker: SyncWorker

    @Before
    fun setUp() {
        context = mockk(relaxed = true)
        workerParams = mockk(relaxed = true)
        syncEngine = mockk()
        syncWorker = SyncWorker(context, workerParams, syncEngine)
    }

    @Test
    fun `doWork returns success when sync engine returns Success`() = runTest {
        coEvery { syncEngine.syncAll() } returns SyncResult.Success

        val result = syncWorker.doWork()

        assertEquals(Result.success(), result)
    }

    @Test
    fun `doWork returns success when sync engine returns NotAuthenticated`() = runTest {
        coEvery { syncEngine.syncAll() } returns SyncResult.NotAuthenticated

        val result = syncWorker.doWork()

        assertEquals(Result.success(), result)
    }

    @Test
    fun `doWork returns retry when sync engine returns TransientError`() = runTest {
        coEvery { syncEngine.syncAll() } returns SyncResult.TransientError(Exception("Network timeout"))

        val result = syncWorker.doWork()

        assertEquals(Result.retry(), result)
    }

    @Test
    fun `doWork returns failure when sync engine returns PermanentError`() = runTest {
        coEvery { syncEngine.syncAll() } returns SyncResult.PermanentError(Exception("Unauthorized 401"))

        val result = syncWorker.doWork()

        assertEquals(Result.failure(), result)
    }
}
