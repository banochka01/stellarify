// Wear OS remote for Resonance. Standalone Android module (no Flutter):
// controls the phone player over the Wearable Data Layer.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val phoneVersion: List<String> = rootProject.file("../pubspec.yaml")
    .readLines()
    .first { it.startsWith("version:") }
    .substringAfter("version:")
    .trim()
    .split("+")
val phoneVersionName = phoneVersion[0]
val phoneVersionCode = phoneVersion.getOrNull(1)?.toInt() ?: 1

android {
    namespace = "app.resonance.wear"
    compileSdk = 36

    defaultConfig {
        // Data Layer pairs apps by identical applicationId + signing key.
        applicationId = "app.resonance.resonance"
        minSdk = 30
        targetSdk = 36
        // Derived from the phone app version (pubspec.yaml `x.y.z+N`): the
        // watch APK shares the applicationId, so its code must be unique and
        // grow with every phone release.
        versionCode = phoneVersionCode * 10 + 1
        versionName = phoneVersionName
    }

    buildTypes {
        release {
            // Must stay identical to :app (android/app/build.gradle.kts), which
            // currently signs release with the debug key: Data Layer pairing
            // requires the same applicationId AND the same signing key.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.01.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.wear.compose:compose-material:1.4.0")
    implementation("androidx.wear.compose:compose-foundation:1.4.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
}
