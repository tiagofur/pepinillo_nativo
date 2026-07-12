package dev.creapolis.pepinillo.di

import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository

@EntryPoint
@InstallIn(SingletonComponent::class)
interface BootstrapEntryPoint {
    fun userPreferencesRepository(): UserPreferencesRepository
}