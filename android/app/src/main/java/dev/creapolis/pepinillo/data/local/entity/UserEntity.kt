package dev.creapolis.pepinillo.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    val email: String,
    val name: String,
    val imageUrl: String? = null,
    val birthDate: String? = null,
    // Column defaults are intentionally NOT declared here. SQLite cannot ALTER column
    // defaults without a full table-rebuild, so `MIGRATION_8_9` is an empty-body
    // migration. Real v8 databases already carry these defaults from MIGRATION_5_6 /
    // MIGRATION_7_8 raw SQL; declaring `@ColumnInfo(defaultValue=...)` would make the
    // entity-declared v9 schema diverge from what the empty migration produces.
    @ColumnInfo(name = "subscriptionTier")
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    @ColumnInfo(name = "emailVerified")
    val emailVerified: Boolean = false,
    @ColumnInfo(name = "aiCreditsBalance")
    val aiCreditsBalance: Int = 0,
    @ColumnInfo(name = "createdAt")
    val createdAt: String = "",
    @ColumnInfo(name = "updatedAt")
    val updatedAt: String = "",
    @ColumnInfo(name = "cachedAt")
    val cachedAt: Long = System.currentTimeMillis(),
)
