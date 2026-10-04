plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rafdev.quranku"
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

    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // GitHub Actions explicitly signs the release APK with apksigner so the
    // final artifact gets deterministic v1/v2/v3 schemes. Local builds can
    // still use the normal Gradle release signing configuration.
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

val patchQuranKuUi by tasks.registering(Exec::class) {
    workingDir(rootProject.projectDir.parentFile)
    commandLine("python3", "scripts/patch_ui_indonesian.py")
}

tasks.named("preBuild").configure {
    dependsOn(patchQuranKuUi)
}
