package dev.creapolis.pepinillo.testing

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences

/**
 * Minimal in-memory [SharedPreferences] used by unit tests that exercise
 * [dev.creapolis.pepinillo.data.WearSnapshotStore] without pulling in Robolectric.
 *
 * Implements only the subset of the contract the production code relies on
 * (getAll / getString / getInt / getLong / getFloat / getBoolean / contains / edit).
 */
class FakeSharedPreferences : SharedPreferences {

    // HashMap (not ConcurrentHashMap): production code writes legitimate null values
    // (e.g. linkedTaskId when no task is linked) and ConcurrentHashMap rejects nulls.
    // Tests are single-threaded so we don't need the concurrency guarantees.
    private val data: MutableMap<String, Any?> = HashMap()

    // --- reads --------------------------------------------------------

    override fun getAll(): Map<String, *> = data.toMap()

    override fun getString(key: String, defValue: String?): String? =
        (data[key] as? String) ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String, defValues: Set<String>?): Set<String>? =
        (data[key] as? Set<String>) ?: defValues

    override fun getInt(key: String, defValue: Int): Int = (data[key] as? Int) ?: defValue
    override fun getLong(key: String, defValue: Long): Long = (data[key] as? Long) ?: defValue
    override fun getFloat(key: String, defValue: Float): Float = (data[key] as? Float) ?: defValue
    override fun getBoolean(key: String, defValue: Boolean): Boolean =
        (data[key] as? Boolean) ?: defValue

    override fun contains(key: String): Boolean = data.containsKey(key)

    // --- listeners (not used by production code) ----------------------

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    // --- writes -------------------------------------------------------

    override fun edit(): SharedPreferences.Editor = Editor()

    inner class Editor : SharedPreferences.Editor {
        private val pending: MutableMap<String, Any?> = LinkedHashMap()
        private var doClear = false

        override fun putString(key: String, value: String?): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putStringSet(
            key: String,
            values: Set<String>?,
        ): SharedPreferences.Editor {
            pending[key] = values
            return this
        }

        override fun putInt(key: String, value: Int): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putLong(key: String, value: Long): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putFloat(key: String, value: Float): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun putBoolean(key: String, value: Boolean): SharedPreferences.Editor {
            pending[key] = value
            return this
        }

        override fun remove(key: String): SharedPreferences.Editor {
            pending.remove(key)
            data.remove(key)
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            doClear = true
            return this
        }

        override fun commit(): Boolean {
            apply()
            return true
        }

        override fun apply() {
            if (doClear) data.clear()
            data.putAll(pending)
            pending.clear()
            doClear = false
        }
    }
}

/**
 * Context that hands out the same [FakeSharedPreferences] regardless of the requested name.
 * Built on [ContextWrapper] so we inherit the abstract [Context] surface without re-implementing
 * every method. Only `getSharedPreferences` is overridden — that is the only entry point
 * [dev.creapolis.pepinillo.data.WearSnapshotStore] uses.
 */
class FakePreferencesContext(
    val backing: FakeSharedPreferences = FakeSharedPreferences(),
) : ContextWrapper(null) {
    override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences = backing
}
