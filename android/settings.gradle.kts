pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.7.3 (Flutter 3.32.0's template default) caps compileSdk at 35;
    // ditto_live 5.1.0 requires 36. 8.10.1 is the lowest AGP that supports
    // compileSdk 36 while still running on the pinned Gradle 8.12.
    id("com.android.application") version "8.10.1" apply false
    // ditto_live 5.1.0 ships modules with Kotlin binary metadata 2.3.0 and
    // pulls kotlin-stdlib 2.3.21 transitively; KGP 2.1.0 refuses both with
    // "metadata is 2.3.0, expected version is 2.1.0". Matches the stdlib
    // version Ditto publishes against.
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
}

include(":app")
