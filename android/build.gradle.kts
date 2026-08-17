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

// Force Flutter plugin Android libraries to compileSdk 36 (app_links AAR metadata).
// Use reflection so root project does not need AGP classes on the buildscript classpath.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val setters = listOf("setCompileSdkVersion", "setCompileSdk")
        for (name in setters) {
            val method = androidExt.javaClass.methods.firstOrNull {
                it.name == name && it.parameterTypes.size == 1
            } ?: continue
            try {
                when (method.parameterTypes[0]) {
                    Int::class.javaPrimitiveType, Int::class.javaObjectType -> method.invoke(androidExt, 36)
                    else -> method.invoke(androidExt, 36)
                }
                break
            } catch (_: Exception) {
                // try next setter
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
