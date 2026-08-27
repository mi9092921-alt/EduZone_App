import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FB-001 (Sentry EDUZONE-3, "Failed to load FirebaseOptions from resource"):
// firebase_core/firebase_messaging were declared in pubspec.yaml and
// Firebase.initializeApp() was called from FcmService, but the
// `com.google.gms.google-services` Gradle plugin was never applied
// anywhere in this project. That plugin is what reads
// android/app/google-services.json at build time and generates the
// values.xml resources (default_web_client_id, google_app_id,
// google_api_key, etc.) that native FirebaseApp auto-initialization
// reads at runtime. Without the plugin applied, those resources never
// exist — so even a developer machine with a real, valid
// google-services.json in place still fails with exactly this error on
// every single launch, which matches the reported repro (same device,
// two runs, both failing).
//
// google-services.json is intentionally gitignored (see .gitignore) —
// it is per-Firebase-project configuration, not committed to the repo —
// so the plugin is applied conditionally on the file actually being
// present locally/in CI. This keeps `flutter build` working on a
// checkout that has no Firebase project wired up yet (push notifications
// simply stay disabled, exactly as FcmService.init()'s existing
// try/catch already assumes), while fixing the crash-path for any
// machine — like the one that generated this Sentry report — that does
// have the file in place.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "[EduZone] android/app/google-services.json not found — skipping " +
            "com.google.gms.google-services plugin. Firebase Messaging will " +
            "stay disabled for this build (FcmService.init() already " +
            "degrades to a no-op + logged error in that case). Place a real " +
            "google-services.json here to enable push notifications."
    )
}

// REL-001: Load the real production keystore credentials from
// android/key.properties. This file is NEVER committed to the repository
// (see .gitignore) — it must be created locally per machine, or written
// from CI secrets at build time (see CI-001). Release builds fail closed
// when the production signing configuration is absent or invalid; there is
// no debug-keystore fallback for release artifacts.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasRealReleaseSigning = keystorePropertiesFile.exists()
if (hasRealReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))

    val requiredSigningProperties = listOf(
        "storeFile",
        "storePassword",
        "keyAlias",
        "keyPassword",
    )
    val missingSigningProperties = requiredSigningProperties.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missingSigningProperties.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is incomplete; missing: ${missingSigningProperties.joinToString(", ")}"
        )
    }

    val releaseKeystore = rootProject.file(keystoreProperties.getProperty("storeFile"))
    if (!releaseKeystore.isFile) {
        throw GradleException(
            "Production release keystore does not exist: ${releaseKeystore.absolutePath}"
        )
    }
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
        // Stable production application ID used by the Android package and Play Console.
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
            // REL-001: a release artifact is never allowed to fall back to the debug keystore.
            // Missing or invalid production signing configuration must fail the actual release
            // task, but must not prevent Gradle configuration or debug/smoke builds.
            if (hasRealReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
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

// Enforce production signing only when a release artifact is actually built.
// Keeping the check on release tasks avoids breaking debug/smoke builds during Gradle
// configuration while preserving the fail-closed release boundary.
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!hasRealReleaseSigning) {
            throw GradleException(
                "Production release builds require android/key.properties with a valid " +
                    "release keystore. Refusing to sign a release artifact with the debug key."
            )
        }
    }
}

tasks.configureEach {
    if (name in setOf("assembleRelease", "bundleRelease", "packageRelease")) {
        dependsOn(verifyReleaseSigning)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
