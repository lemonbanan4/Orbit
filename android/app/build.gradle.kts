import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

// 🚀 FIXED FOR KOTLIN DSL: Load your key.properties variables securely
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.invokerlab.orbit"
    compileSdk = 36
    // Pinned instead of the flutter.ndkVersion default -- that default
    // (28.2.13676358) is present under the SDK's ndk/ dir but missing its
    // build/cmake/android.toolchain.cmake entirely (an incomplete/corrupted
    // local install), which fails native compilation for any plugin using
    // JNI (e.g. speech_to_text's jni dependency) on release builds.
    // 27.1.12297006 is fully installed and verified working.
    ndkVersion = "27.1.12297006"

    defaultConfig {
        applicationId = "com.invokerlab.orbit"
        
        // Cast the configuration variables safely into Kotlin integers.
        // minSdk is pinned to 26 (Android 8.0) rather than the Flutter
        // default -- the health plugin's own Android library (Health
        // Connect) requires minSdkVersion 26, and Gradle's manifest merger
        // fails the build if the app module's minSdk is lower than any
        // dependency's.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            
            // Handle the file routing safely with an explicit type check
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            storeFile = if (storeFilePath != null) file(storeFilePath) else null
            
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            // Apply the secure signature properties
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true   // required by flutter_local_notifications
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}