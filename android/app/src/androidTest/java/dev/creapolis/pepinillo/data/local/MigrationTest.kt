package dev.creapolis.pepinillo.data.local

import androidx.room.testing.MigrationTestHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Validates Room migrations for [PepinilloDatabase].
 *
 * Schema JSON exports live under `app/schemas/` (one file per DB version) and are
 * exposed to the test via the `androidTest.assets.srcDirs("$projectDir/schemas")`
 * configuration in `app/build.gradle.kts`. `MigrationTestHelper` uses them as the
 * source of truth: after running a migration it compares the resulting database
 * against the JSON at the target version.
 *
 * Historical gap: `exportSchema` was `false` until v9, so JSON exports for v1..v7
 * were never produced and cannot be retroactively reconstructed for migrated DBs.
 * Coverage therefore starts at the v8 → v9 transition (the migration added by
 * Sub-fase 2A). Going forward every version bump will have its JSON exported and
 * can be covered here.
 *
 * ## TOOLCHAIN DEFERRAL — tests are structurally correct but cannot run yet
 *
 * This test class compiles and is structurally correct, but **cannot execute**
 * under the current Room 2.8.4 + Kotlin 2.1.0 toolchain. Room 2.8.4 transitively
 * pulls `kotlin-metadata-jvm:2.2.0` (via `room-compiler-processing`), which forces
 * `kotlin-stdlib` to 2.2.0 on a Kotlin 2.1.0 project. When `MigrationTestHelper`
 * tries to load any of the exported JSONs under `app/schemas/`, Room's compiled
 * `FieldBundle$$serializer` throws `AbstractMethodError`
 * (`typeParametersSerializers()` has no implementation on the 2.1.0-resolved
 * serialization runtime). The `resolutionStrategy.force` serialization pin in
 * `app/build.gradle.kts` mitigates the KSP export path but not the load path used
 * here.
 *
 * **Tracking issue: https://github.com/tiagofur/pepinillo_nativo/issues/53**
 * (A-C3 from sub-fase 2A judgment day). When the Kotlin toolchain is bumped to
 * 2.2.0, these tests will run as-is — no code changes required here.
 *
 * To run (once the toolchain is bumped): `./gradlew :app:connectedDebugAndroidTest`
 * (requires a device/emulator) or right-click → Run from Android Studio.
 */
@RunWith(AndroidJUnit4::class)
class MigrationTest {

    private val dbName = "migration-test.db"

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        PepinilloDatabase::class.java,
    )

    /**
     * Sanity check: a fresh DB created at v9 must match the exported `9.json`.
     * Validates that the entity-declared schema (UserEntity no longer carries
     * `@ColumnInfo(defaultValue=...)` on its 6 columns — see R2-C1) produces the
     * expected column metadata. The empty `MIGRATION_8_9` body then matches the
     * v8 → v9 schema delta exactly, since neither side declares defaults.
     */
    @Test
    fun freshDatabase_atVersion9_matchesExportedSchema() {
        helper.createDatabase(dbName, 9).close()
    }

    /**
     * v8 → v9: the migration added by Sub-fase 2A.
     *
     * After R2-C1, `MIGRATION_8_9` is empty and there is **no schema delta at all**
     * between v8 and v9: the `@ColumnInfo(defaultValue=...)` annotations that 2A
     * originally added to `UserEntity` were dropped (R2-C1) because SQLite cannot
     * ALTER column defaults without a full table-rebuild, and the empty migration
     * body could not reproduce them. Both `8.json` and `9.json` now declare the
     * `users` columns without defaults, so the v8 → v9 schemas are identical. Room
     * still requires the migration because the version number changed — without it,
     * upgrading from v8 crashes with "A migration from 8 to 9 was required but not
     * found".
     *
     * The helper first builds a v8 DB from `8.json`, then runs `MIGRATION_8_9`
     * and validates the result against `9.json`. Because the migration does not
     * touch the schema, the validation confirms v8 and v9 are byte-equivalent.
     */
    @Test
    fun migrate8To9_matchesExportedSchema() {
        helper.createDatabase(dbName, 8).close()
        val migrated = helper.runMigrationsAndValidate(
            dbName,
            9,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_8_9,
        )
        migrated.close()
    }

    /**
     * Smoke test: `MIGRATION_8_9` must declare the correct endpoints. This catches
     * accidental copy-paste of an existing `Migration(N, M)` constructor.
     */
    @Test
    fun migration8To9_declaresCorrectEndpoints() {
        val migration = PepinilloDatabase.MIGRATION_8_9
        assertEquals(8, migration.startVersion)
        assertEquals(9, migration.endVersion)
    }

    /**
     * v9 → v10: adds `is_deleted` and `updated_at` columns to `subtasks`.
     *
     * This is the only migration in the chain that performs real schema work
     * (ALTER TABLE ADD COLUMN ×2). The helper first builds a v9 DB from `9.json`,
     * then runs `MIGRATION_9_10` and validates the result against `10.json`.
     */
    @Test
    fun migrate9To10_matchesExportedSchema() {
        helper.createDatabase(dbName, 9).close()
        val migrated = helper.runMigrationsAndValidate(
            dbName,
            10,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_9_10,
        )
        migrated.close()
    }

    /**
     * Column-presence test: after running `MIGRATION_9_10`, the `subtasks` table
     * must expose the new `is_deleted` (and `updated_at`) column.
     *
     * This is a behavioural assertion independent of the full schema-equality check
     * in [migrate9To10_matchesExportedSchema] — it guards against the migration
     * silently no-op'ing or mis-naming the new column.
     */
    @Test
    fun migration9To10_addsSubtaskIsDeletedColumn() {
        helper.createDatabase(dbName, 9).close()
        val migrated = helper.runMigrationsAndValidate(
            dbName,
            10,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_9_10,
        )
        // SELECT * ... LIMIT 0 yields no rows but the cursor still reports the
        // table's column names, so getColumnIndex() is authoritative for presence.
        migrated.query("SELECT * FROM subtasks LIMIT 0").use { cursor ->
            assertTrue("subtasks.is_deleted column missing", cursor.getColumnIndex("is_deleted") >= 0)
            assertTrue("subtasks.updated_at column missing", cursor.getColumnIndex("updated_at") >= 0)
        }
        migrated.close()
    }

    /**
     * Smoke test: `MIGRATION_9_10` must declare the correct endpoints.
     */
    @Test
    fun migration9To10_declaresCorrectEndpoints() {
        val migration = PepinilloDatabase.MIGRATION_9_10
        assertEquals(9, migration.startVersion)
        assertEquals(10, migration.endVersion)
    }

    // ── MIGRATION_10_11: Drop raw_payload from productivity_reports ──

    /**
     * v10 → v11: drops the redundant `raw_payload` column from `productivity_reports`.
     *
     * The migration recreates the table without `raw_payload` and copies all other columns.
     * This test validates the forward migration matches the exported schema.
     */
    @Test
    fun migrate10To11_matchesExportedSchema() {
        helper.createDatabase(dbName, 10).close()
        val migrated = helper.runMigrationsAndValidate(
            dbName,
            11,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_10_11,
        )
        migrated.close()
    }

    /**
     * Column-absence test: after running `MIGRATION_10_11`, the `productivity_reports`
     * table must NOT expose the `raw_payload` column.
     */
    @Test
    fun migration10To11_dropsRawPayloadColumn() {
        helper.createDatabase(dbName, 10).close()
        val migrated = helper.runMigrationsAndValidate(
            dbName,
            11,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_10_11,
        )
        migrated.query("SELECT * FROM productivity_reports LIMIT 0").use { cursor ->
            val rawPayloadIndex = cursor.getColumnIndex("raw_payload")
            assertTrue(
                "raw_payload column should be removed after migration",
                rawPayloadIndex < 0,
            )
            // Verify other columns still exist
            assertTrue("id column missing", cursor.getColumnIndex("id") >= 0)
            assertTrue("period column missing", cursor.getColumnIndex("period") >= 0)
            assertTrue("title column missing", cursor.getColumnIndex("title") >= 0)
            assertTrue("highlights column missing", cursor.getColumnIndex("highlights") >= 0)
            assertTrue("insights column missing", cursor.getColumnIndex("insights") >= 0)
            assertTrue("recommendations column missing", cursor.getColumnIndex("recommendations") >= 0)
        }
        migrated.close()
    }

    /**
     * Smoke test: `MIGRATION_10_11` must declare the correct endpoints.
     */
    @Test
    fun migration10To11_declaresCorrectEndpoints() {
        val migration = PepinilloDatabase.MIGRATION_10_11
        assertEquals(10, migration.startVersion)
        assertEquals(11, migration.endVersion)
    }

    /**
     * serverId preservation test: tasks retain serverId after migration chain.
     *
     * This test creates a v10 DB, inserts a task with a serverId, then runs
     * migrations through v11 and verifies the serverId is preserved.
     */
    @Test
    fun serverIdPreservedThroughMigration10To11() {
        val db = helper.createDatabase(dbName, 10)
        // Insert a task with server_id (column exists since v2)
        db.execSQL(
            "INSERT INTO tasks (id, title, server_id, is_dirty, is_deleted) " +
                "VALUES ('task-1', 'Test Task', 42, 1, 0)",
        )
        db.close()

        val migrated = helper.runMigrationsAndValidate(
            dbName,
            11,
            /* validateDroppedTables = */ true,
            PepinilloDatabase.MIGRATION_10_11,
        )

        // Verify server_id is preserved
        val cursor = migrated.query("SELECT server_id FROM tasks WHERE id = 'task-1'")
        assertTrue("Task should exist after migration", cursor.moveToFirst())
        val serverId = cursor.getLong(0)
        assertEquals("server_id should be preserved", 42L, serverId)
        cursor.close()
        migrated.close()
    }
}

