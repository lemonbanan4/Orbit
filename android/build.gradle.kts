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

// The :app module explicitly targets JVM 17 (see app/build.gradle.kts), but
// third-party plugin subprojects (pulled straight from pub.dev, e.g.
// home_widget) don't set their own jvmTarget and fall back to the Kotlin
// Gradle Plugin's default of 1.8 -- which only actually breaks the release
// build, since that's when R8/minification forces full recompilation and
// bytecode inlining across module boundaries. A dependency compiled at 11
// (androidx.glance, kotlinx.coroutines) can't be inlined into code compiled
// at 1.8, producing "Cannot inline bytecode built with JVM target 11 into
// bytecode that is being built with JVM target 1.8". Force every subproject
// to the same JVM 17 target the app itself already uses.
subprojects {
    afterEvaluate {
        extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>()
            ?.compilerOptions
            ?.jvmTarget
            ?.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        tasks.withType<org.gradle.api.tasks.compile.JavaCompile> {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        // Some plugin subprojects (e.g. jni-1.0.0, a transitive native
        // dependency) set their own `ndkVersion = flutter.ndkVersion`
        // directly in their build.gradle, which the :app-level override in
        // app/build.gradle.kts doesn't reach. flutter.ndkVersion currently
        // resolves to 28.2.13676358, which is present under the SDK's ndk/
        // dir but missing build/cmake/android.toolchain.cmake entirely (an
        // incomplete/corrupted local install) -- force every subproject
        // onto 27.1.12297006, which is fully installed and verified working.
        extensions.findByType<com.android.build.gradle.BaseExtension>()
            ?.ndkVersion = "27.1.12297006"
    }
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