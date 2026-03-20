package dev.creapolis.pepinillo.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dev.creapolis.pepinillo.domain.report.OnDeviceReportGenerator
import dev.creapolis.pepinillo.domain.report.ReportGenerator
import dev.creapolis.pepinillo.domain.report.ReportGeneratorImpl
import dev.creapolis.pepinillo.domain.report.TemplateReportGenerator
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ReportModule {

    @Provides
    @Singleton
    fun provideReportGenerator(
        onDeviceGenerator: OnDeviceReportGenerator,
        templateGenerator: TemplateReportGenerator,
    ): ReportGenerator {
        return ReportGeneratorImpl(onDeviceGenerator, templateGenerator)
    }
}
