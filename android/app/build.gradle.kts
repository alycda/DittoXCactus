plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dittoxcactus.mesh_rag"
    // ditto_live 5.1.0's Android artifacts (com.ditto:{ditto-cinterop,util,
    // transports,rustls}-android) all declare minCompileSdk=36, so this cannot
    // follow flutter.compileSdkVersion — Flutter 3.32.0 pins that to 35.
    // Revert to `flutter.compileSdkVersion` once the pinned Flutter ships 36.
    compileSdk = 36
    // Cactus + ditto_live + record + permission_handler all require NDK 27.
    // Same pin as tools/determinism_harness/ — discovered there first when
    // the harness's first build hit the manifest-merger error.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.dittoxcactus.mesh_rag"
        // record (a transitive Cactus dep) needs API 23+; pin to 24 to match
        // the harness and stay aligned with the plan's documented floor.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
