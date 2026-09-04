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
    // app_links (via portone_flutter) requires compileSdk >= 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // 스테이징 빌드를 운영 앱과 한 폰에 나란히 깔기 위한 접미사.
        // 기본은 빈 문자열 — 아무것도 안 넘기면 지금까지와 동일한 앱이다.
        // 나란히 설치하려면: ROUNDER_APP_ID_SUFFIX=.staging
        val appIdSuffix = (
            project.findProperty("rounderAppIdSuffix") as String?
                ?: System.getenv("ROUNDER_APP_ID_SUFFIX")
                ?: ""
        ).trim()
        applicationId = "com.golfrounder.golf$appIdSuffix"
        manifestPlaceholders["appLabel"] =
            if (appIdSuffix.isEmpty()) "라운더" else "라운더 (스테이징)"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Play already used ≤29. Codemagic reads build-number from pubspec.yaml.
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
            // Codemagic android_signing exports CM_KEYSTORE_*.
            // ios-first 등 키스토어 없는 CI에서는 NPE 내지 말고 로컬 key.properties로 폴백.
            val cmPath = System.getenv("CM_KEYSTORE_PATH")
            if (System.getenv("CI") == "true" && !cmPath.isNullOrBlank()) {
                storeFile = file(cmPath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
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
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
