package dev.creapolis.pepinillo.data.repository

import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.UpdateProfileRequest
import dev.creapolis.pepinillo.core.network.UserDto
import dev.creapolis.pepinillo.data.local.dao.UserDao
import dev.creapolis.pepinillo.data.local.entity.UserEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UserRepository @Inject constructor(
    private val userDao: UserDao,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
) {
    fun observeCachedUser(): Flow<UserEntity?> {
        val userId = authStore.getUserId() ?: return flowOf(null)
        return userDao.observeById(userId)
    }

    suspend fun fetchAndCacheProfile(): Result<UserEntity> {
        return when (val result = apiClient.getMe()) {
            is NetworkResult.Success -> {
                val entity = result.data.toEntity()
                userDao.upsert(entity)
                authStore.saveUser(entity.id, entity.name, entity.email)
                Result.success(entity)
            }
            is NetworkResult.Error -> Result.failure(
                Exception("API error ${result.code}: ${result.message}")
            )
            is NetworkResult.NetworkError -> Result.failure(result.exception)
        }
    }

    suspend fun updateProfile(request: UpdateProfileRequest): Result<UserEntity> {
        return when (val result = apiClient.updateMe(request)) {
            is NetworkResult.Success -> {
                val entity = result.data.toEntity()
                userDao.upsert(entity)
                authStore.saveUser(entity.id, entity.name, entity.email)
                Result.success(entity)
            }
            is NetworkResult.Error -> Result.failure(
                Exception("API error ${result.code}: ${result.message}")
            )
            is NetworkResult.NetworkError -> Result.failure(result.exception)
        }
    }

    suspend fun cacheUserFromDto(dto: UserDto) {
        val entity = dto.toEntity()
        userDao.upsert(entity)
    }

    suspend fun clearCache() {
        userDao.deleteAll()
    }

    private fun UserDto.toEntity() = UserEntity(
        id = id,
        email = email,
        name = name,
        imageUrl = imageUrl,
        birthDate = birthDate,
        subscriptionTier = subscriptionTier,
        subscriptionExpiresAt = subscriptionExpiresAt,
        emailVerified = emailVerified,
        aiCreditsBalance = aiCreditsBalance,
        createdAt = createdAt,
        updatedAt = updatedAt,
        cachedAt = System.currentTimeMillis(),
    )
}
