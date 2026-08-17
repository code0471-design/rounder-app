allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// MUST run before evaluationDependsOn / afterEvaluate.
// app_links requires compileSdk >= 36; portone_flutter plugins ship with 34.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        for (methodName in listOf("setCompileSdk", "setCompileSdkVersion")) {
            val applied =
                runCatching {
                    androidExt.javaClass
                        .getMethod(methodName, Int::class.javaPrimitiveType)
                        .invoke(androidExt, 36)
                }.isSuccess
            if (applied) break
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
