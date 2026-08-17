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

subprojects {
    project.evaluationDependsOn(":app")
}

// Force Flutter plugin libraries to compileSdk 36 (app_links AAR metadata / portone_flutter).
subprojects {
    afterEvaluate {
        if (!plugins.hasPlugin("com.android.library")) return@afterEvaluate
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val ok =
            runCatching {
                android.javaClass
                    .getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                    .invoke(android, 36)
            }.isSuccess ||
                runCatching {
                    android.javaClass
                        .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(android, 36)
                }.isSuccess ||
                runCatching {
                    android.javaClass.methods
                        .first { it.name == "compileSdkVersion" && it.parameterCount == 1 }
                        .invoke(android, 36)
                }.isSuccess
        if (!ok) {
            logger.warn("Could not set compileSdk=36 on ${project.name}")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
