import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.golfrounder.golf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.golfrounder.golf"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Kakao Login redirect scheme: kakao{NATIVE_APP_KEY}
        val localProps = Properties()
        val localFile = rootProject.file("local.properties")
        if (localFile.exists()) {
            localFile.inputStream().use { localProps.load(it) }
        }
        val kakaoKey = (
            localProps.getProperty("KAKAO_NATIVE_APP_KEY")
                ?: project.findProperty("KAKAO_NATIVE_APP_KEY") as String?
                ?: System.getenv("KAKAO_NATIVE_APP_KEY")
                ?: "a4b6744dd621da26f0cf3244e9ea8fb5"
        ).trim()
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = kakaoKey
    }

    signingConfigs {
        create("release") {
            // Codemagic Android code signing env vars (preferred in CI)
            val cmKeystore = System.getenv("CM_KEYSTORE_PATH")
            val cmPassword = System.getenv("CM_KEYSTORE_PASSWORD")
            val cmAlias = System.getenv("CM_KEY_ALIAS")
            val cmKeyPassword = System.getenv("CM_KEY_PASSWORD")
            if (!cmKeystore.isNullOrBlank() &&
                !cmPassword.isNullOrBlank() &&
                !cmAlias.isNullOrBlank() &&
                !cmKeyPassword.isNullOrBlank()
            ) {
                storeFile = file(cmKeystore)
                storePassword = cmPassword
                keyAlias = cmAlias
                keyPassword = cmKeyPassword
            } else if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null) {
                releaseSigning
            } else {
                // Local fallback only — Play Console rejects debug-signed AABs
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
