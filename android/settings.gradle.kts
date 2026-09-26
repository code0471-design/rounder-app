pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")

// play_install_referrer 가 자기 classpath 로 AGP 8.13 을 또 받으면
// Codemagic 이 dl.google.com 에서 잘린다. 루트 9.0.1 을 재사용한다.
gradle.beforeProject {
    if (name != "play_install_referrer") return@beforeProject
    val classpath = runCatching { buildscript.configurations.getByName("classpath") }
        .getOrNull() ?: return@beforeProject
    classpath.resolutionStrategy.eachDependency {
        if (requested.group == "com.android.tools.build" &&
            requested.name == "gradle") {
            useVersion("9.0.1")
        }
    }
}
