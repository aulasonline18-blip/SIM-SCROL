import java.io.FileInputStream
import java.util.Base64
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

fun dartDefineValue(name: String): String? {
    val rawDefines = (project.findProperty("dart-defines") as String?)
        ?: (project.findProperty("dart-defines-${name}") as String?)
        ?: return null
    return rawDefines
        .split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .firstOrNull { decoded -> decoded.startsWith("$name=") }
        ?.substringAfter("=")
}

fun boolDartDefine(name: String, fallback: Boolean = false): Boolean =
    dartDefineValue(name)
        ?.lowercase()
        ?.let { it == "1" || it == "true" || it == "yes" }
        ?: fallback

val simApplicationId = stringProperty("SIM_ANDROID_APPLICATION_ID", "com.aulasonline.sim")
val simReleaseServerUrl = dartDefineValue("SIM_SERVER_URL") ?: ""
val simOperationalReleaseAllowCleartext =
    boolProperty("SIM_ANDROID_OPERATIONAL_RELEASE_ALLOW_CLEARTEXT", false)
val simReleaseSigningReady =
    !signingValue("storeFile").isNullOrBlank() &&
        !signingValue("storePassword").isNullOrBlank() &&
        !signingValue("keyAlias").isNullOrBlank() &&
        !signingValue("keyPassword").isNullOrBlank()
val simRequireReleaseSigning = boolProperty("SIM_REQUIRE_RELEASE_SIGNING", true)

android {
    namespace = "com.aulasonline.sim"
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
        manifestPlaceholders["simUsesCleartextTraffic"] = "false"
        manifestPlaceholders["simNetworkSecurityConfig"] =
            "@xml/network_security_config"
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
        debug {
            manifestPlaceholders["simUsesCleartextTraffic"] =
                boolProperty("SIM_ANDROID_DEBUG_ALLOW_CLEARTEXT", true).toString()
        }
        release {
            if (simReleaseServerUrl.startsWith("http://")) {
                throw GradleException(
                    "SIM_SERVER_URL must use HTTPS for release builds."
                )
            }
            if (simRequireReleaseSigning && !simReleaseSigningReady) {
                throw GradleException(
                    "Release signing is required. Configure android/key.properties or SIM_ANDROID_* environment variables."
                )
            }
            manifestPlaceholders["simUsesCleartextTraffic"] =
                simOperationalReleaseAllowCleartext.toString()
            manifestPlaceholders["simNetworkSecurityConfig"] =
                if (simOperationalReleaseAllowCleartext) {
                    "@xml/network_security_config_operational_release"
                } else {
                    "@xml/network_security_config"
                }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = !simOperationalReleaseAllowCleartext
            isShrinkResources = !simOperationalReleaseAllowCleartext
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
