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

subprojects {
    val forceCompileSdk = {
        extensions.findByName("android")?.let { androidExtension ->
            val compileSdkSetter = androidExtension.javaClass.methods.find { method ->
                method.name == "setCompileSdkVersion" &&
                    method.parameterTypes.size == 1 &&
                    method.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            compileSdkSetter?.invoke(androidExtension, 36)
        }
    }

    if (state.executed) {
        forceCompileSdk()
    } else {
        afterEvaluate {
            forceCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
