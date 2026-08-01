import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// REL-001: Load the real production keystore credentials from
// android/key.properties. This file is NEVER committed to the repository
// (see .gitignore) — it must be created locally per machine, or written
// from CI secrets at build time (see CI-001). If it is absent (e.g. on a
// fresh developer checkout who only needs `flutter run --release` locally
// for testing, not a real store submission), we intentionally fall back to
// the Android debug keystore so local development keeps working — but that
// fallback path must NEVER be used for an actual release artifact that
// leaves this machine. See SECURITY.md and IMPLEMENTATION.md (REL-001).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasRealReleaseSigning = keystorePropertiesFile.exists()
if (hasRealReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.eduzone.learn.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eduzone.learn.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasRealReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // ABI splitting is intentionally NOT configured here via `splits { abi { ... } }`.
    // The Flutter Gradle Plugin already sets android.defaultConfig.ndk.abiFilters
    // automatically based on the `--target-platform` flag (or the default ABI
    // list) passed to the `flutter build` command. Declaring a manual `splits`
    // block in parallel causes a hard Gradle conflict:
    //   "Conflicting configuration ... in ndk abiFilters cannot be present
    //    when splits abi filters are set"
    // To get one smaller APK per architecture, use Flutter's own flag instead:
    //   flutter build apk --split-per-abi --dart-define-from-file=.env
    // This produces app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk,
    // and app-x86_64-release.apk under build/app/outputs/flutter-apk/.
    // (If distributing exclusively via Google Play with an AAB + Play App
    // Signing, Play already performs this split server-side and no extra
    // flag is needed — just `flutter build appbundle --release`.)

    buildTypes {
        release {
            // REL-001: Use the real production signing config when
            // android/key.properties is present (real machine/CI build).
            // Fall back to the debug keystore ONLY for local convenience
            // (`flutter run --release` on a dev machine with no keystore
            // configured yet) — this path must never produce a build that
            // is uploaded anywhere. A loud build-time warning is emitted
            // below so this is never silently shipped.
            signingConfig = if (hasRealReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n\n" +
                    "⚠️  ⚠️  ⚠️  RELEASE BUILD IS SIGNED WITH THE DEBUG KEYSTORE  ⚠️  ⚠️  ⚠️\n" +
                    "android/key.properties was not found, so this 'release' build type\n" +
                    "is falling back to the DEBUG signing key. This build is NOT suitable\n" +
                    "for any Play Store submission or distribution outside this machine.\n" +
                    "See REL-001 in IMPLEMENTATION.md for how to generate a real\n" +
                    "production keystore and android/key.properties.\n\n"
                )
                signingConfigs.getByName("debug")
            }

            // Enables R8 code shrinking + obfuscation and resource shrinking.
            // Meaningfully reduces APK/AAB size given the size of pubspec.yaml's
            // dependency tree, and adds a baseline layer of reverse-engineering
            // resistance on top of the app's client-side encryption logic.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
