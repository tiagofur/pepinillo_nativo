# Wear OS ProGuard rules

# ── Compose ──
-keep class androidx.compose.** { *; }

# ── Wear Compose ──
-keep class androidx.wear.compose.** { *; }

# ── Wear Tiles & Complications ──
-keep class androidx.wear.tiles.** { *; }
-keep class dev.creapolis.pepinillo.tile.** { *; }
-keep class dev.creapolis.pepinillo.complication.** { *; }

# ── Google Play Services Wearable (DataLayer) ──
-keep class com.google.android.gms.wearable.** { *; }
-dontwarn com.google.android.gms.wearable.**

# ── Wear listener service ──
-keep class dev.creapolis.pepinillo.sync.WearSyncListenerService { *; }

# ── Kotlin Coroutines ──
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# ── ProtoLayout ──
-keep class androidx.wear.protolayout.** { *; }
-dontwarn androidx.wear.protolayout.**
