plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Keep the existing Kotlin source package; the installed application ID is changed below.
    namespace = "com.damarcreative.quran"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.rafdev.quranku"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Store JNI libraries uncompressed so the APK can be 16 KB page-aligned.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // CI builds the APK unsigned, then signs the final aligned artifact with apksigner.
    val manualApkSigning = System.getenv("MANUAL_APK_SIGNING") == "true"

    signingConfigs {
        create("release") {
            if (!manualApkSigning) {
                val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
                val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
                val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")

                require(!keystorePath.isNullOrBlank()) {
                    "ANDROID_KEYSTORE_PATH is required for a local Gradle-signed release build."
                }
                require(!keystorePassword.isNullOrBlank()) {
                    "ANDROID_KEYSTORE_PASSWORD is required for a local Gradle-signed release build."
                }
                require(!keyAliasValue.isNullOrBlank()) {
                    "ANDROID_KEY_ALIAS is required for a local Gradle-signed release build."
                }
                require(!keyPasswordValue.isNullOrBlank()) {
                    "ANDROID_KEY_PASSWORD is required for a local Gradle-signed release build."
                }

                storeFile = file(keystorePath)
                storePassword = keystorePassword
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            if (!manualApkSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
