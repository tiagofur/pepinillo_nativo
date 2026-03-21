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

# ── Kotlinx Serialization ──
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class dev.creapolis.pepinillo.**$$serializer { *; }
-keepclassmembers class dev.creapolis.pepinillo.** {
    *** Companion;
}
-keepclasseswithmembers class dev.creapolis.pepinillo.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ── Kotlin Coroutines ──
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# ── Google Credential Manager / Sign-In ──
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }

# ── RevenueCat ──
-keep class com.revenuecat.purchases.** { *; }
