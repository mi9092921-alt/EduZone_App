pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Declared here (apply false) so the version is resolved once for the
    // whole build; actually applied conditionally in app/build.gradle.kts
    // only when android/app/google-services.json is present (see that
    // file for the "why conditional" rationale — this plugin is what
    // turns the JSON into the values.xml resources FirebaseApp reads at
    // runtime; without it, Firebase.initializeApp() fails with "Failed
    // to load FirebaseOptions from resource" even when the JSON file
    // exists on disk).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
