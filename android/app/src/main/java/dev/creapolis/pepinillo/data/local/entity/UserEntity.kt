package dev.creapolis.pepinillo.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    val email: String,
    val name: String,
    val imageUrl: String? = null,
    val birthDate: String? = null,
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    val emailVerified: Boolean = false,
    val createdAt: String = "",
    val updatedAt: String = "",
    val cachedAt: Long = System.currentTimeMillis(),
)
