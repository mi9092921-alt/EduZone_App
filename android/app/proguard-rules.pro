# freeRASP ProGuard / R8 rules
# Reference: https://github.com/talsec/Free-RASP-Flutter

# Keep native method signatures to prevent UnsatisfiedLinkError at runtime
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep all freeRASP / Talsec classes intact — do NOT obfuscate or strip
-keep class com.aheaditec.talsec_security.** { *; }

# Preserve annotations used by freeRASP internally
-keepattributes *Annotation*

# Retain source file and line number metadata for crash reporting
-keepattributes SourceFile,LineNumberTable

# Keep custom exceptions so threat callbacks surface correctly
-keep public class * extends java.lang.Exception

# ---------------------------------------------------------------------------
# Added when enabling isMinifyEnabled/isShrinkResources (see build.gradle.kts).
# These guard packages that load native libraries or use reflection/JNI,
# which R8 cannot trace statically and may otherwise strip.
# ---------------------------------------------------------------------------

# media_kit (libmpv) — native playback engine loaded via JNI/dynamic linking.
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-dontwarn com.alexmercerind.**

# flutter_secure_storage — uses Android Keystore/Keychain APIs via reflection
# on some OEM/API-level combinations.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Supabase (gotrue/postgrest/realtime) + underlying websocket/http clients —
# keep models used with json_serializable/freezed style (de)serialization,
# and the websocket implementation used for realtime channels.
-keep class io.supabase.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod
-dontwarn io.supabase.**
-dontwarn okhttp3.**
-dontwarn okio.**

# device_info_plus — reflects on Build.* fields on some vendor ROMs.
-keep class android.os.Build { *; }
-keep class android.os.Build$VERSION { *; }