plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ditto.meshrag.mesh_rag_demo"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ditto.meshrag.mesh_rag_demo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ditto_live's transitive com.ditto:rustls requires minSdk 24; cactus requires API 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // ditto_live 5.0.0 dropped the consumer-proguard-rules.pro that v4
            // shipped (KMP rewrite). Without keep rules, R8 strips the classes
            // libdittoffi.so reflects on during rustls init; the app aborts
            // pre-main with "Cannot initialize rustls without SDK class loader"
            // → SIGABRT. Workaround per Sergiu Bulzan in #docs (2026-05-08).
            // See SDKS-3594 (workaround), SDKS-2626 (long-term: ship the
            // rules with the SDK so apps don't need this file).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
