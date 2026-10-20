# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# ── Glance App Widgets ──
-keep class dev.creapolis.pepinillo.widget.** { *; }
-keep class androidx.glance.** { *; }

# ── Hilt ──
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keepclasseswithmembers class * {
    @dagger.hilt.* <methods>;
}

# ── Room ──
-keep class dev.creapolis.pepinillo.data.local.entity.** { *; }
-keep class dev.creapolis.pepinillo.data.local.dao.** { *; }

# ── Ktor ──
-keep class io.ktor.** { *; }
-keepclassmembers class io.ktor.** { *; }
-dontwarn io.ktor.**

# ── OkHttp ──
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Kotlinx Serialization (comprehensive rules) ──
-keepattributes *Annotation*, InnerClasses
-keepattributes RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations
-dontnote kotlinx.serialization.AnnotationsKt

# Keep kotlinx.serialization core
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# Keep all @Serializable classes and their generated serializers
-if @kotlinx.serialization.Serializable class **
-keep class <1> { *; }

-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep generated $$serializer classes
-keep,includedescriptorclasses class dev.creapolis.pepinillo.**$$serializer { *; }

# Keep Companion objects with serializer()
-keepclassmembers class dev.creapolis.pepinillo.** {
    *** Companion;
}
-keepclasseswithmembers class dev.creapolis.pepinillo.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep all network model classes explicitly
-keep class dev.creapolis.pepinillo.core.network.** { *; }
-keepclassmembers class dev.creapolis.pepinillo.core.network.** { *; }

# ── Kotlin Coroutines ──
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# ── Google Credential Manager / Sign-In ──
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }

# ── RevenueCat ──
-keep class com.revenuecat.purchases.** { *; }

# ── Play measurement references AdvertisingIdClient optionally; the app does
# not use Advertising ID. Silence R8 (generated missing_rules.txt guidance).
-dontwarn com.google.android.gms.ads.identifier.AdvertisingIdClient$Info
-dontwarn com.google.android.gms.ads.identifier.AdvertisingIdClient
