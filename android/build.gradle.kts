// 1. Keep your modern plugin management
plugins {
    id("com.android.application") version "9.1.0" apply false
    id("com.android.library") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
    // dev.flutter.flutter-gradle-plugin is provided via the includeBuild composite
    // in settings.gradle.kts — do NOT declare it here with a version.
}

// With android.builtInKotlin=false, some Firebase plugins (cloud_functions,
// firebase_analytics, firebase_remote_config, firebase_storage) conditionally skip
// applying `kotlin-android` for AGP 9+ (their build files contain the line inside an
// `if (agpMajor < 9)` guard). Flutter's Gradle plugin detects KGP via regex and
// therefore does NOT re-apply it — leaving those modules with no Kotlin compilation
// at all and causing "cannot find symbol" errors in GeneratedPluginRegistrant.java.
//
// Fix: after each plugin subproject is evaluated, apply KGP to any Android library
// that still doesn't have it. This is safe because:
//  - Subprojects that applied KGP themselves are skipped (hasPlugin check).
//  - KGP 2.2.20 is already on the classpath via the root plugins block.
subprojects {
    // Apply KGP during the configuration phase (the only window it can be applied).
    // Needed for Firebase plugins whose build files contain:
    //   if (agpMajor < 9) { apply plugin: 'kotlin-android' }
    // Flutter's regex detects that line and skips re-applying KGP, but the guard
    // means KGP is never actually applied at AGP 9 runtime — leaving those modules
    // with no Kotlin compilation and causing "cannot find symbol" in Java code.
    pluginManager.withPlugin("com.android.library") {
        if (!plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

// Redirect every subproject's build directory from android/<name>/build/ to
// <flutter_root>/build/<name>/. Without this, the Flutter Gradle plugin copies
// the assembled APK into android/app/build/outputs/flutter-apk/ instead of
// <flutter_root>/build/app/outputs/flutter-apk/, which is the only path the
// `flutter run` / `flutter build apk` tool scans for the output APK.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Keep your allprojects block
allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
            force("androidx.glance:glance:1.1.1")
        }
    }
}

// 3. You DO NOT need a separate buildscript block if you use the plugins block correctly.
// The "plugins" block above already accomplishes what the "buildscript" block did in older versions.