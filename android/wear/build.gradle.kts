import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "dev.creapolis.pepinillo"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.creapolis.pepinillo"
        minSdk = 26
        targetSdk = 36
        versionCode = 10021
        versionName = "3.0.0"
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    val hasReleaseSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .all { key -> keystoreProperties[key]?.toString()?.isNotBlank() == true }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"]!!.toString())
                storePassword = keystoreProperties["storePassword"]!!.toString()
                keyAlias = keystoreProperties["keyAlias"]!!.toString()
                keyPassword = keystoreProperties["keyPassword"]!!.toString()
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material.icons.extended)

    implementation(libs.androidx.wear)
    implementation(libs.androidx.wear.ongoing)
    implementation(libs.androidx.wear.compose.foundation)
    implementation(libs.androidx.wear.compose.material)
    implementation(libs.androidx.wear.compose.navigation)

    implementation(libs.play.services.wearable)
    implementation(libs.kotlinx.coroutines.play.services)
    implementation(libs.androidx.wear.tiles)
    implementation(libs.androidx.wear.complications.datasource)
    implementation(libs.androidx.concurrent.futures)
    implementation(libs.androidx.protolayout)
    implementation(libs.androidx.protolayout.material)
    implementation(libs.androidx.protolayout.expression)

    testImplementation(libs.junit)
    // org.json is bundled in the Android runtime; provide a real impl for JVM unit tests
    // so WearDataStore.parseTasksJson (org.json.JSONArray) can be exercised in tests.
    testImplementation("org.json:json:20240303")

    debugImplementation(libs.androidx.compose.ui.tooling)
}
