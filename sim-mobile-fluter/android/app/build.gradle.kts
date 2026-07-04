import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(name: String): String? =
    keystoreProperties.getProperty(name)
        ?: System.getenv("SIM_ANDROID_${name.uppercase()}")

fun stringProperty(name: String, fallback: String): String =
    (project.findProperty(name) as String?)
        ?: System.getenv(name)
        ?: fallback

fun boolProperty(name: String, fallback: Boolean = false): Boolean =
    ((project.findProperty(name) as String?) ?: System.getenv(name))
        ?.lowercase()
        ?.let { it == "1" || it == "true" || it == "yes" }
        ?: fallback

val simApplicationId = stringProperty("SIM_ANDROID_APPLICATION_ID", "com.example.sim_mobile")
val simReleaseSigningReady =
    !signingValue("storeFile").isNullOrBlank() &&
        !signingValue("storePassword").isNullOrBlank() &&
        !signingValue("keyAlias").isNullOrBlank() &&
        !signingValue("keyPassword").isNullOrBlank()
val simRequireReleaseSigning = boolProperty("SIM_REQUIRE_RELEASE_SIGNING")

android {
    namespace = "com.example.sim_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = simApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingValue("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = rootProject.file(storeFilePath)
                storePassword = signingValue("storePassword")
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (simRequireReleaseSigning && !simReleaseSigningReady) {
                throw GradleException(
                    "Release signing is required. Configure android/key.properties or SIM_ANDROID_* environment variables."
                )
            }
            signingConfig = signingConfigs.getByName(
                if (simReleaseSigningReady) "release" else "debug"
            )
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
